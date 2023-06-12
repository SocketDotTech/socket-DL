import fs from "fs";
import { BigNumberish, Wallet, constants, ethers } from "ethers";

import { getProviderFromChainName, switchboards } from "../constants";
import {
  deployedAddressPath,
  getInstance,
  getSwitchboardAddress,
  storeAllAddresses,
} from "./utils";
import {
  CORE_CONTRACTS,
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  IntegrationTypes,
  MainnetIds,
  NativeSwitchboard,
  TestnetIds,
  isTestnet,
  networkToChainSlug,
} from "../../src";
import registerSwitchBoard from "./scripts/registerSwitchboard";
import { arrayify, defaultAbiCoder, keccak256, id } from "ethers/lib/utils";
import {
  capacitorType,
  chains,
  maxPacketLength,
  mode,
  executionManagerVersion,
  overrides,
  msgValueMaxThreshold,
} from "./config";

export const main = async () => {
  try {
    if (!fs.existsSync(deployedAddressPath(mode))) {
      throw new Error("addresses.json not found");
    }
    let addresses: DeploymentAddresses = JSON.parse(
      fs.readFileSync(deployedAddressPath(mode), "utf-8")
    );
    let chain: ChainSlug;

    await Promise.all(
      chains.map(async (chain) => {
        if (!addresses[chain]) return;

        const providerInstance = getProviderFromChainName(
          networkToChainSlug[chain]
        );
        const socketSigner: Wallet = new Wallet(
          process.env.SOCKET_SIGNER_KEY as string,
          providerInstance
        );

        let addr: ChainSocketAddresses = addresses[chain]!;

        const list = isTestnet(chain) ? TestnetIds : MainnetIds;
        const siblingSlugs: ChainSlug[] = list.filter(
          (chainSlug) => chainSlug !== chain && chains.includes(chainSlug)
        );

        await configureExecutionManager(
          addr,
          executionManagerVersion,
          chain,
          siblingSlugs,
          socketSigner
        );

        if (!addr["integrations"]) return;

        const integrations = addr["integrations"] ?? {};
        const integrationList = Object.keys(integrations).filter((chain) =>
          chains.includes(parseInt(chain) as ChainSlug)
        );

        console.log(`Configuring for ${chain}`);

        for (let sibling of integrationList) {
          const config = integrations[sibling][IntegrationTypes.native];
          if (!config) continue;
          addr = await registerSwitchBoard(
            config["switchboard"],
            sibling,
            capacitorType,
            maxPacketLength,
            socketSigner,
            IntegrationTypes.native,
            addr
          );
        }

        // register fast
        for (let sibling of siblingSlugs) {
          addr = await registerSwitchBoard(
            addr[CORE_CONTRACTS.FastSwitchboard],
            sibling,
            capacitorType,
            maxPacketLength,
            socketSigner,
            IntegrationTypes.fast,
            addr
          );
        }
        // register optimistic
        for (let sibling of siblingSlugs) {
          addr = await registerSwitchBoard(
            addr[CORE_CONTRACTS.OptimisticSwitchboard],
            sibling,
            capacitorType,
            maxPacketLength,
            socketSigner,
            IntegrationTypes.optimistic,
            addr
          );
        }

        addresses[chain] = addr;

        console.log(`Configuring for ${chain} - COMPLETED`);
      })
    );

    await storeAllAddresses(addresses, mode);

    await setRemoteSwitchboards(addresses);
  } catch (error) {
    console.log("Error while sending transaction", error);
  }
};

const configureExecutionManager = async (
  addr: ChainSocketAddresses,
  contractName: string,
  chain: ChainSlug,
  siblingSlugs: ChainSlug[],
  socketSigner: Wallet
) => {
  try {
    console.log(
      "configuring execution manager for ",
      chain,
      addr[contractName]
    );

    let executionManagerContract, socketBatcherContract;
    executionManagerContract = (
      await getInstance(contractName, addr[contractName]!)
    ).connect(socketSigner);

    let nextNonce = (
      await executionManagerContract.nextNonce(socketSigner.address)
    ).toNumber();
    console.log({ nextNonce });

    let requests: any = [];

    await Promise.all(
      siblingSlugs.map(async (siblingSlug) => {
        let currentValue = await executionManagerContract.msgValueMaxThreshold(
          siblingSlug
        );

        if (
          currentValue.toString() ==
          msgValueMaxThreshold[siblingSlug]?.toString()
        ) {
          console.log("already set, returning ", { currentValue });
          return;
        }

        const digest = keccak256(
          defaultAbiCoder.encode(
            ["bytes32", "address", "uint32", "uint32", "uint256", "uint256"],
            [
              id("MSG_VALUE_MAX_THRESHOLD_UPDATE"),
              addr[contractName]!,
              chain,
              siblingSlug,
              nextNonce,
              msgValueMaxThreshold[siblingSlug],
            ]
          )
        );

        const signature = await socketSigner.signMessage(arrayify(digest));

        let request = {
          signature,
          dstChainSlug: siblingSlug,
          nonce: nextNonce++,
          fees: msgValueMaxThreshold[siblingSlug],
          functionSelector: "0xa1885700", // setMsgValueMaxThreshold
        };
        requests.push(request);
      })
    );

    if (requests.length === 0) return;
    socketBatcherContract = (
      await getInstance("SocketBatcher", addr[CORE_CONTRACTS.SocketBatcher]!)
    ).connect(socketSigner);

    let tx = await socketBatcherContract.setExecutionFeesBatch(
      addr[contractName]!,
      requests,
      { ...overrides[chain] }
    );
    console.log(chain, tx.hash);
    await tx.wait();
  } catch (error) {
    console.log("error while configuring execution manager: ", error);
  }
};

const setRemoteSwitchboards = async (addresses) => {
  try {
    let srcChains = Object.keys(addresses);
    await Promise.all(
      srcChains.map(async (srcChain) => {
        console.log(`Configuring remote switchboards for ${srcChain}`);

        const providerInstance = getProviderFromChainName(
          networkToChainSlug[srcChain]
        );
        const socketSigner: Wallet = new Wallet(
          process.env.SOCKET_SIGNER_KEY as string,
          providerInstance
        );

        for (let dstChain in addresses[srcChain]?.["integrations"]) {
          const dstConfig = addresses[srcChain]["integrations"][dstChain];

          if (dstConfig?.[IntegrationTypes.native]) {
            const srcSwitchboardType =
              switchboards[networkToChainSlug[srcChain]]?.[
                networkToChainSlug[dstChain]
              ]?.["switchboard"];
            const dstSwitchboardAddress = getSwitchboardAddress(
              srcChain,
              IntegrationTypes.native,
              addresses?.[dstChain]
            );
            if (!dstSwitchboardAddress) continue;

            const srcSwitchboardAddress =
              dstConfig?.[IntegrationTypes.native]["switchboard"];

            let functionName, sbContract;
            if (srcSwitchboardType === NativeSwitchboard.POLYGON_L1) {
              sbContract = (
                await getInstance("PolygonL1Switchboard", srcSwitchboardAddress)
              ).connect(socketSigner);

              const fxChild = await sbContract.fxChildTunnel();
              if (fxChild !== constants.AddressZero) continue;

              functionName = "setFxChildTunnel";
              console.log(
                `Setting ${dstSwitchboardAddress} fx child tunnel in ${srcSwitchboardAddress} on networks ${srcChain}-${dstChain}`
              );
            } else if (srcSwitchboardType === NativeSwitchboard.POLYGON_L2) {
              sbContract = (
                await getInstance("PolygonL2Switchboard", srcSwitchboardAddress)
              ).connect(socketSigner);

              const fxRoot = await sbContract.fxRootTunnel();
              if (fxRoot !== constants.AddressZero) continue;

              functionName = "setFxRootTunnel";
              console.log(
                `Setting ${dstSwitchboardAddress} fx root tunnel in ${srcSwitchboardAddress} on networks ${srcChain}-${dstChain}`
              );
            } else {
              sbContract = (
                await getInstance(
                  "ArbitrumL1Switchboard",
                  srcSwitchboardAddress
                )
              ).connect(socketSigner);

              const remoteNativeSwitchboard =
                await sbContract.remoteNativeSwitchboard();
              if (
                remoteNativeSwitchboard.toLowerCase() ===
                dstSwitchboardAddress.toLowerCase()
              )
                continue;

              functionName = "updateRemoteNativeSwitchboard";
              console.log(
                `Setting ${dstSwitchboardAddress} remote switchboard in ${srcSwitchboardAddress} on networks ${srcChain}-${dstChain}`
              );
            }

            const tx = await sbContract
              .connect(socketSigner)
              [functionName](dstSwitchboardAddress, {
                ...overrides[await socketSigner.getChainId()],
              });
            console.log(srcChain, tx.hash);
            await tx.wait();
          }
        }

        console.log(
          `Configuring remote switchboards for ${srcChain} - COMPLETED`
        );
      })
    );
  } catch (error) {
    console.error(error);
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

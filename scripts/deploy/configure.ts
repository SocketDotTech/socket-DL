import fs from "fs";
import { Wallet, constants } from "ethers";

import { getProviderFromChainSlug, switchboards } from "../constants";
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
  ChainSlugToKey,
} from "../../src";
import registerSwitchboardForSibling from "./scripts/registerSwitchboard";
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

        const providerInstance = getProviderFromChainSlug(
          chain as any as ChainSlug
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

        const socket = (
          await getInstance(CORE_CONTRACTS.Socket, addr.Socket)
        ).connect(socketSigner);

        let tx;
        const currentEM = await socket.executionManager__();
        if (
          currentEM.toLowerCase() !==
          addr[executionManagerVersion]?.toLowerCase()
        ) {
          tx = await socket.setExecutionManager(addr[executionManagerVersion], {
            ...overrides[await socketSigner.getChainId()],
          });
          console.log("updateExecutionManager", tx.hash);
          await tx.wait();
        }

        const currentTM = await socket.transmitManager__();
        if (currentTM.toLowerCase() !== addr.TransmitManager?.toLowerCase()) {
          tx = await socket.setTransmitManager(addr.TransmitManager, {
            ...overrides[await socketSigner.getChainId()],
          });
          console.log("updateTransmitManager", tx.hash);
          await tx.wait();
        }

        const integrations = addr["integrations"] ?? {};
        const integrationList = Object.keys(integrations).filter((chain) =>
          chains.includes(parseInt(chain) as ChainSlug)
        );

        console.log(`Configuring for ${chain}`);

        for (let sibling of integrationList) {
          const config = integrations[sibling][IntegrationTypes.native];
          if (!config) continue;

          const siblingSwitchboard = getSwitchboardAddress(
            chain,
            IntegrationTypes.native,
            addresses?.[sibling]
          );

          if (!siblingSwitchboard) continue;

          addr = await registerSwitchboardForSibling(
            config["switchboard"],
            siblingSwitchboard,
            sibling,
            capacitorType,
            maxPacketLength,
            socketSigner,
            IntegrationTypes.native,
            addr
          );
        }

        // register fast2
        for (let sibling of siblingSlugs) {
          const siblingSwitchboard = getSwitchboardAddress(
            chain,
            IntegrationTypes.fast,
            // IntegrationTypes.fast2,
            addresses?.[sibling]
          );

          if (!siblingSwitchboard || !addr[CORE_CONTRACTS.FastSwitchboard])
          // if (!siblingSwitchboard || !addr[CORE_CONTRACTS.FastSwitchboard2])
            continue;

          addr = await registerSwitchboardForSibling(
            addr[CORE_CONTRACTS.FastSwitchboard],
            // addr[CORE_CONTRACTS.FastSwitchboard2],
            siblingSwitchboard,
            sibling,
            capacitorType,
            maxPacketLength,
            socketSigner,
            IntegrationTypes.fast,
            // IntegrationTypes.fast2,
            addr
          );
        }

        // register optimistic
        for (let sibling of siblingSlugs) {
          const siblingSwitchboard = getSwitchboardAddress(
            chain,
            IntegrationTypes.optimistic,
            addresses?.[sibling]
          );

          if (!siblingSwitchboard) continue;

          addr = await registerSwitchboardForSibling(
            addr[CORE_CONTRACTS.OptimisticSwitchboard],
            siblingSwitchboard,
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
    await setupPolygonNativeSwitchboard(addresses);
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
    // console.log({ nextNonce });

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
          // console.log("already set, returning ", { currentValue });
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

const setupPolygonNativeSwitchboard = async (addresses) => {
  try {
    let srcChains = Object.keys(addresses).filter((chain) =>
      ["5", "1", "80001", "137"].includes(chain)
    );

    await Promise.all(
      srcChains.map(async (srcChain) => {
        console.log(`Configuring for ${srcChain}`);

        const providerInstance = getProviderFromChainSlug(
          srcChain as any as ChainSlug
        );
        const socketSigner: Wallet = new Wallet(
          process.env.SOCKET_SIGNER_KEY as string,
          providerInstance
        );

        for (let dstChain in addresses[srcChain]?.["integrations"]) {
          const dstConfig = addresses[srcChain]["integrations"][dstChain];
          if (!dstConfig?.[IntegrationTypes.native]) continue;

          const srcSwitchboardType =
            switchboards[ChainSlugToKey[srcChain]]?.[
              ChainSlugToKey[dstChain]
            ]?.["switchboard"];

          const dstSwitchboardAddress = getSwitchboardAddress(
            srcChain,
            IntegrationTypes.native,
            addresses?.[dstChain]
          );
          if (!dstSwitchboardAddress) continue;

          const srcSwitchboardAddress =
            dstConfig?.[IntegrationTypes.native]["switchboard"];

          if (srcSwitchboardType === NativeSwitchboard.POLYGON_L1) {
            const sbContract = (
              await getInstance("PolygonL1Switchboard", srcSwitchboardAddress)
            ).connect(socketSigner);

            const fxChild = await sbContract.fxChildTunnel();
            if (fxChild !== constants.AddressZero) continue;
            console.log(
              `Setting ${dstSwitchboardAddress} fx child tunnel in ${srcSwitchboardAddress} on networks ${srcChain}-${dstChain}`
            );

            const tx = await sbContract
              .connect(socketSigner)
              .setFxChildTunnel(dstSwitchboardAddress, {
                ...overrides[await socketSigner.getChainId()],
              });
            console.log(srcChain, tx.hash);
            await tx.wait();
          } else if (srcSwitchboardType === NativeSwitchboard.POLYGON_L2) {
            const sbContract = (
              await getInstance("PolygonL2Switchboard", srcSwitchboardAddress)
            ).connect(socketSigner);

            const fxRoot = await sbContract.fxRootTunnel();
            if (fxRoot !== constants.AddressZero) continue;
            console.log(
              `Setting ${dstSwitchboardAddress} fx root tunnel in ${srcSwitchboardAddress} on networks ${srcChain}-${dstChain}`
            );

            const tx = await sbContract
              .connect(socketSigner)
              .setFxRootTunnel(dstSwitchboardAddress, {
                ...overrides[await socketSigner.getChainId()],
              });
            console.log(srcChain, tx.hash);
            await tx.wait();
          } else continue;
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

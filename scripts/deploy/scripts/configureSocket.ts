import { Wallet, constants } from "ethers";

import { getProviderFromChainSlug, switchboards } from "../../constants";
import { getInstance, getSwitchboardAddress } from "../utils";
import {
  CORE_CONTRACTS,
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  IntegrationTypes,
  NativeSwitchboard,
  ChainSlugToKey,
} from "../../../src";
import registerSwitchboardForSibling from "../scripts/registerSwitchboard";
import { arrayify, defaultAbiCoder, keccak256, id } from "ethers/lib/utils";
import {
  capacitorType,
  maxPacketLength,
  executionManagerVersion,
  overrides,
  msgValueMaxThreshold,
} from "../config";
import { handleOps, isKinto } from "../utils/kinto/kinto";

export const registerSwitchboards = async (
  chain: ChainSlug,
  siblingSlugs: ChainSlug[],
  switchboardContractName: string,
  integrationType: IntegrationTypes,
  addr: ChainSocketAddresses,
  addresses: DeploymentAddresses,
  socketSigner: Wallet
) => {
  for (let sibling of siblingSlugs) {
    const siblingSwitchboard = getSwitchboardAddress(
      chain,
      integrationType,
      addresses?.[sibling]
    );

    if (!siblingSwitchboard || !addr[switchboardContractName]) continue;

    addr = await registerSwitchboardForSibling(
      addr[switchboardContractName],
      siblingSwitchboard,
      sibling,
      capacitorType,
      maxPacketLength,
      socketSigner,
      integrationType,
      addr
    );
  }

  return addr;
};

export const setManagers = async (
  addr: ChainSocketAddresses,
  socketSigner: Wallet
) => {
  const socket = (
    await getInstance(CORE_CONTRACTS.Socket, addr.Socket)
  ).connect(socketSigner);

  let tx;
  const currentEM = await socket.executionManager__();
  if (
    currentEM.toLowerCase() !== addr[executionManagerVersion]?.toLowerCase()
  ) {
    const txRequest = await socket.populateTransaction.setExecutionManager(
      addr[executionManagerVersion],
      {
        ...overrides(await socketSigner.getChainId()),
      }
    );

    if (isKinto(await socketSigner.getChainId())) {
      tx = await handleOps(
        process.env.SOCKET_OWNER_ADDRESS,
        [txRequest],
        process.env.SOCKET_SIGNER_KEY
      );
    } else {
      tx = await (await socket.signer.sendTransaction(txRequest)).wait();
    }
    console.log("updateExecutionManager", tx.transactionHash);
  }

  const currentTM = await socket.transmitManager__();
  if (currentTM.toLowerCase() !== addr.TransmitManager?.toLowerCase()) {
    const txRequest = await socket.populateTransaction.setTransmitManager(
      addr.TransmitManager,
      {
        ...overrides(await socketSigner.getChainId()),
      }
    );

    if (isKinto(await socketSigner.getChainId())) {
      tx = await handleOps(
        process.env.SOCKET_OWNER_ADDRESS,
        [txRequest],
        process.env.SOCKET_SIGNER_KEY
      );
    } else {
      tx = await (await socket.signer.sendTransaction(txRequest)).wait();
    }

    console.log("updateTransmitManager", tx.transactionHash);
  }
};

export const configureExecutionManager = async (
  contractName: string,
  emAddress: string,
  socketBatcherAddress: string,
  chain: ChainSlug,
  siblingSlugs: ChainSlug[],
  socketSigner: Wallet
) => {
  try {
    console.log("configuring execution manager for ", chain, emAddress);

    let executionManagerContract, socketBatcherContract;
    executionManagerContract = (
      await getInstance(contractName, emAddress!)
    ).connect(socketSigner);

    let nextNonce = (
      await executionManagerContract.nextNonce(socketSigner.address)
    ).toNumber();

    let requests: any = [];
    await Promise.all(
      siblingSlugs.map(async (siblingSlug) => {
        let currentValue = await executionManagerContract.msgValueMaxThreshold(
          siblingSlug
        );

        if (
          currentValue.toString() ==
          msgValueMaxThreshold(siblingSlug)?.toString()
        ) {
          return;
        }

        const digest = keccak256(
          defaultAbiCoder.encode(
            ["bytes32", "address", "uint32", "uint32", "uint256", "uint256"],
            [
              id("MSG_VALUE_MAX_THRESHOLD_UPDATE"),
              emAddress!,
              chain,
              siblingSlug,
              nextNonce,
              msgValueMaxThreshold(siblingSlug),
            ]
          )
        );

        const signature = await socketSigner.signMessage(arrayify(digest));

        let request = {
          signature,
          dstChainSlug: siblingSlug,
          nonce: nextNonce++,
          fees: msgValueMaxThreshold(siblingSlug),
          functionSelector: "0xa1885700", // setMsgValueMaxThreshold
        };
        requests.push(request);
      })
    );

    if (requests.length === 0) return;
    socketBatcherContract = (
      await getInstance("SocketBatcher", socketBatcherAddress)
    ).connect(socketSigner);

    let tx: any;
    const txRequest =
      await socketBatcherContract.populateTransaction.setExecutionFeesBatch(
        emAddress,
        requests,
        { ...overrides(chain) }
      );

    if (isKinto(chain)) {
      tx = await handleOps(
        process.env.SOCKET_OWNER_ADDRESS,
        [txRequest],
        process.env.SOCKET_SIGNER_KEY
      );
    } else {
      tx = await (
        await socketBatcherContract.signer.sendTransaction(txRequest)
      ).wait();
    }

    console.log("configured EM for ", chain, tx.transactionHash);
  } catch (error) {
    console.log("error while configuring execution manager: ", error);
  }
};

export const setupPolygonNativeSwitchboard = async (addresses) => {
  try {
    let srcChains = Object.keys(addresses)
      .filter((chain) => ["1", "137"].includes(chain))
      .map((c) => parseInt(c) as ChainSlug);

    await Promise.all(
      srcChains.map(async (srcChain: ChainSlug) => {
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
              ChainSlugToKey[parseInt(dstChain) as ChainSlug]
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

            let tx;
            const contract = await sbContract.connect(socketSigner);
            const txRequest =
              await contract.populateTransaction.setFxChildTunnel(
                dstSwitchboardAddress,
                {
                  ...overrides(await socketSigner.getChainId()),
                }
              );

            if (isKinto(await socketSigner.getChainId())) {
              tx = await handleOps(
                process.env.SOCKET_OWNER_ADDRESS,
                [txRequest],
                process.env.SOCKET_SIGNER_KEY
              );
            } else {
              tx = await (
                await contract.signer.sendTransaction(txRequest)
              ).wait();
            }

            console.log(srcChain, tx.transactionHash);
          } else if (srcSwitchboardType === NativeSwitchboard.POLYGON_L2) {
            const sbContract = (
              await getInstance("PolygonL2Switchboard", srcSwitchboardAddress)
            ).connect(socketSigner);

            const fxRoot = await sbContract.fxRootTunnel();
            if (fxRoot !== constants.AddressZero) continue;
            console.log(
              `Setting ${dstSwitchboardAddress} fx root tunnel in ${srcSwitchboardAddress} on networks ${srcChain}-${dstChain}`
            );

            let tx;
            const contract = await sbContract.connect(socketSigner);
            const txRequest =
              await contract.populateTransaction.setFxRootTunnel(
                dstSwitchboardAddress,
                {
                  ...overrides(await socketSigner.getChainId()),
                }
              );

            if (isKinto(await socketSigner.getChainId())) {
              tx = await handleOps(
                process.env.SOCKET_OWNER_ADDRESS,
                [txRequest],
                process.env.SOCKET_SIGNER_KEY
              );
            } else {
              tx = await (
                await contract.signer.sendTransaction(txRequest)
              ).wait();
            }
            console.log(srcChain, tx.transactionHash);
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

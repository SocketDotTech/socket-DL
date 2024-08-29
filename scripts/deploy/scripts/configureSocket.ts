import { constants } from "ethers";

import { switchboards } from "../../constants";
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
  overrides,
  msgValueMaxThreshold,
} from "../config/config";
import { SocketSigner } from "@socket.tech/dl-common";
import { getSocketSigner } from "../utils/socket-signer";
import { multicall } from "./multicall";

export const registerSwitchboards = async (
  chain: ChainSlug,
  siblingSlugs: ChainSlug[],
  switchboardContractName: string,
  integrationType: IntegrationTypes,
  addr: ChainSocketAddresses,
  addresses: DeploymentAddresses,
  socketSigner: SocketSigner
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
  socketSigner: SocketSigner,
  executionManagerVersion: CORE_CONTRACTS
) => {
  const socket = (
    await getInstance(CORE_CONTRACTS.Socket, addr.Socket)
  ).connect(socketSigner);

  let tx;
  const currentEM = await socket.executionManager__();
  if (
    currentEM.toLowerCase() !== addr[executionManagerVersion]?.toLowerCase()
  ) {
    const transaction = {
      to: socket.address,
      data: socket.encodeFunctionData("setExecutionManager(address)", [
        addr[executionManagerVersion],
      ]),
      ...overrides(await socketSigner.getChainId()),
    };

    const isSubmitted = await socketSigner.isTxHashSubmitted(transaction);
    if (isSubmitted) return;

    const tx = await socketSigner.sendTransaction(transaction);
    console.log("updateExecutionManager", tx.hash);
    await tx.wait();
  }

  const currentTM = await socket.transmitManager__();
  if (currentTM.toLowerCase() !== addr.TransmitManager?.toLowerCase()) {
    const transaction = {
      to: socket.address,
      data: socket.encodeFunctionData("setTransmitManager(address)", [
        addr.TransmitManager,
      ]),
      ...overrides(await socketSigner.getChainId()),
    };

    const isSubmitted = await socketSigner.isTxHashSubmitted(transaction);
    if (isSubmitted) return;

    const tx = await socketSigner.sendTransaction(transaction);
    console.log("updateTransmitManager", tx.hash);
    await tx.wait();
  }
};

export const configureExecutionManager = async (
  contractName: string,
  emAddress: string,
  socketBatcherAddress: string,
  chain: ChainSlug,
  siblingSlugs: ChainSlug[],
  socketSigner: SocketSigner
) => {
  try {
    console.log("configuring execution manager for ", chain, emAddress);

    const executionManagerContract = (
      await getInstance(contractName, emAddress!)
    ).connect(socketSigner);

    const socketBatcherContract = (
      await getInstance("SocketBatcher", socketBatcherAddress)
    ).connect(socketSigner);

    let nextNonce = (
      await executionManagerContract.nextNonce(socketSigner.address)
    ).toNumber();

    const signatureMap = new Map<ChainSlug | number, string>();
    const siblingsToConfigure: ChainSlug[] = [];

    const calls = [];
    siblingSlugs.map((s) =>
      calls.push({
        target: executionManagerContract.address,
        callData: executionManagerContract.interface.encodeFunctionData(
          "msgValueMaxThreshold",
          [s]
        ),
      })
    );

    const result = await multicall(socketBatcherContract, calls);
    siblingSlugs.map(async (siblingSlug, index) => {
      const currentValue = result[index];

      if (
        currentValue.toString() == msgValueMaxThreshold(siblingSlug)?.toString()
      ) {
        return;
      }

      siblingsToConfigure.push(siblingSlug);
    });

    await Promise.all(
      siblingsToConfigure.map(async (siblingSlug) => {
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
        signatureMap.set(siblingSlug, signature);
      })
    );

    let requests: any = [];
    siblingsToConfigure.sort().map((siblingSlug) => {
      let request = {
        signature: signatureMap.get(siblingSlug),
        dstChainSlug: siblingSlug,
        nonce: nextNonce++,
        perGasCost: 0,
        perByteCost: 0,
        overhead: 0,
        fees: msgValueMaxThreshold(siblingSlug),
        functionSelector: "0xa1885700", // setMsgValueMaxThreshold
      };
      requests.push(request);
    });

    if (requests.length === 0) return;

    let tx = await socketBatcherContract.setExecutionFeesBatch(
      emAddress,
      requests,
      { ...overrides(chain) }
    );
    console.log("configured EM for ", chain, tx.hash);
    await tx.wait();
  } catch (error) {
    console.log("error while configuring execution manager: ", error);
  }
};

export const setupPolygonNativeSwitchboard = async (addresses, safeChains) => {
  try {
    let srcChains = Object.keys(addresses)
      .filter((chain) => ["1", "137"].includes(chain))
      .map((c) => parseInt(c) as ChainSlug);

    for (let index = 0; index < srcChains.length; index++) {
      const srcChain: ChainSlug = srcChains[index];

      console.log(`Configuring for ${srcChain}`);
      const socketSigner: SocketSigner = await getSocketSigner(
        srcChain,
        addresses[srcChain],
        safeChains.includes(srcChain)
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

        let transaction;
        if (srcSwitchboardType === NativeSwitchboard.POLYGON_L1) {
          const sbContract = (
            await getInstance("PolygonL1Switchboard", srcSwitchboardAddress)
          ).connect(socketSigner);

          const fxChild = await sbContract.fxChildTunnel();
          if (fxChild !== constants.AddressZero) continue;
          console.log(
            `Setting ${dstSwitchboardAddress} fx child tunnel in ${srcSwitchboardAddress} on networks ${srcChain}-${dstChain}`
          );

          transaction = {
            to: sbContract.address,
            data: sbContract.encodeFunctionData("setFxChildTunnel(address)", [
              dstSwitchboardAddress,
            ]),
            ...overrides(await socketSigner.getChainId()),
          };
        } else if (srcSwitchboardType === NativeSwitchboard.POLYGON_L2) {
          const sbContract = (
            await getInstance("PolygonL2Switchboard", srcSwitchboardAddress)
          ).connect(socketSigner);

          const fxRoot = await sbContract.fxRootTunnel();
          if (fxRoot !== constants.AddressZero) continue;
          console.log(
            `Setting ${dstSwitchboardAddress} fx root tunnel in ${srcSwitchboardAddress} on networks ${srcChain}-${dstChain}`
          );

          transaction = {
            to: sbContract.address,
            data: sbContract.encodeFunctionData("setFxRootTunnel(address)", [
              dstSwitchboardAddress,
            ]),
            ...overrides(await socketSigner.getChainId()),
          };
        }

        if (!transaction) continue;

        const isSubmitted = await socketSigner.isTxHashSubmitted(transaction);
        if (isSubmitted) return;
        const tx = await socketSigner.sendTransaction(transaction);
        console.log(srcSwitchboardType, tx.hash, srcChain, dstChain);
        await tx.wait();
      }
      console.log(
        `Configuring remote switchboards for ${srcChain} - COMPLETED`
      );
    }
  } catch (error) {
    console.error(error);
  }
};

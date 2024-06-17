import { arrayify, defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import { Contract, Wallet, constants } from "ethers";

import OwnableABIInterface from "@socket.tech/dl-core/artifacts/abi/Ownable.json";
import { PacketInfo, VERSION_HASH, getPacketInfo, packMessageId } from "./util";
import { getProviderFromChainSlug } from "../../constants";
import { deploymentMode } from "../rpcConfig";
import { TxData, ChainSlug, getAllAddresses, ChainTxData } from "../../../src";
import { prodFeesUpdaterSupportedChainSlugs } from "../constants";

const randomPrivateKey =
  "59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";

export const getSealTxData = async (
  chainSlug: ChainSlug,
  signer: Wallet,
  packetDetails: PacketInfo
) => {
  const digest = keccak256(
    defaultAbiCoder.encode(
      ["bytes32", "uint32", "bytes32", "bytes32"],
      [VERSION_HASH, chainSlug, packetDetails.packetId, packetDetails.root]
    )
  );
  const signature = await signer.signMessage(arrayify(digest));
  const sealBatchDataArgs = [1, packetDetails.capacitor, signature];

  return sealBatchDataArgs;
};

export const getProposeTxData = async (
  chainSlug: ChainSlug,
  signer: Wallet,
  packetDetails: PacketInfo,
  switchboardSimulatorAddress: string
) => {
  const digest = keccak256(
    defaultAbiCoder.encode(
      ["bytes32", "uint32", "bytes32", "bytes32"],
      [VERSION_HASH, chainSlug, packetDetails.packetId, packetDetails.root]
    )
  );
  const signature = await signer.signMessage(arrayify(digest));
  const proposeBatchDataArgs = [
    packetDetails.packetId,
    packetDetails.root,
    switchboardSimulatorAddress,
    signature,
  ];
  return proposeBatchDataArgs;
};

export const getAttestTxData = async (
  chainSlug: ChainSlug,
  signer: Wallet,
  packetDetails: PacketInfo,
  switchboardSimulatorAddress: string
) => {
  const digest = keccak256(
    defaultAbiCoder.encode(
      ["address", "uint32", "bytes32", "uint256", "bytes32"],
      [
        switchboardSimulatorAddress,
        chainSlug,
        packetDetails.packetId,
        "0",
        packetDetails.root,
      ]
    )
  );
  const signature = await signer.signMessage(arrayify(digest));
  const attestBatchDataArgs = [
    packetDetails.packetId,
    chainSlug,
    packetDetails.root,
    signature,
  ];
  return attestBatchDataArgs;
};

export const getExecuteTxData = async (
  chainSlug: ChainSlug,
  signer: Wallet,
  packetDetails: PacketInfo,
  counterAddress: string
) => {
  const digest = keccak256(defaultAbiCoder.encode(["uint256"], ["0"]));
  const signature = await signer.signMessage(arrayify(digest));
  const msgId = packMessageId(chainSlug, counterAddress, "10");

  const executionDetails = {
    packetId: packetDetails.packetId,
    proposalCount: 0,
    executionGasLimit: 100000,
    decapacitorProof: constants.HashZero,
    signature,
  };
  const msgDetails = {
    msgId,
    executionFee: 100000,
    minMsgGasLimit: 100000,
    executionParams: constants.HashZero,
    payload: constants.HashZero,
  };

  const executeBatchDataArgs = [executionDetails, msgDetails];
  return executeBatchDataArgs;
};

export const getTxData = async (): Promise<TxData> => {
  // any provider, just for signing purpose
  const signer = new Wallet(
    randomPrivateKey,
    getProviderFromChainSlug(ChainSlug.SEPOLIA)
  );
  const addresses = getAllAddresses(deploymentMode);
  const allChainSlugs: ChainSlug[] = prodFeesUpdaterSupportedChainSlugs()
    .map((c) => c as ChainSlug)
    .filter((c) => addresses[c]?.["SocketSimulator"]);

  const txData: TxData = {};
  for (const chainSlug of allChainSlugs) {
    console.log(`Getting tx data for ${chainSlug}`);
    const packetInfo = await getPacketInfo(
      chainSlug,
      addresses[chainSlug]?.["CapacitorSimulator"]
    );

    const sbSimulatorAddress = addresses[chainSlug]?.["SwitchboardSimulator"];
    if (sbSimulatorAddress === undefined)
      throw new Error("Sb simulator not found!");

    const sealTxData = await getSealTxData(chainSlug, signer, packetInfo);
    const proposeTxData = await getProposeTxData(
      chainSlug,
      signer,
      packetInfo,
      sbSimulatorAddress
    );
    const attestTxData = await getAttestTxData(
      chainSlug,
      signer,
      packetInfo,
      sbSimulatorAddress
    );
    const executeTxData = await getExecuteTxData(
      chainSlug,
      signer,
      packetInfo,
      addresses[chainSlug]?.["Counter"]
    );

    const simulatorContract = new Contract(
      sbSimulatorAddress,
      OwnableABIInterface,
      getProviderFromChainSlug(chainSlug)
    );
    const owner = await simulatorContract.owner();

    txData[chainSlug] = {
      sealTxData,
      proposeTxData,
      attestTxData,
      executeTxData,
      owner,
    };
  }

  return txData;
};

export const getChainTxData = (
  chainSlug: ChainSlug,
  txData: TxData
): ChainTxData => {
  if (!txData[chainSlug]) return undefined;
  return txData[chainSlug];
};

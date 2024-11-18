import { config as dotenvConfig } from "dotenv";
import { BigNumber, ethers } from "ethers";
import Counter from "../../../../out/Counter.sol/Counter.json";
import Socket from "../../../../out/Socket.sol/Socket.json";
import { ChainSlug } from "../../../../src";
import { getAPIBaseURL, getAddresses, relayTx } from "../../utils";
dotenvConfig();

import { formatEther } from "ethers/lib/utils";
import { getProviderFromChainSlug } from "../../../constants/networks";
import { mode, overrides } from "../../config/config";

const counterAddAmount = 100;

export const LoadTestHelperABI = [
  {
    inputs: [],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "counter_",
        type: "address",
      },
      {
        internalType: "uint32",
        name: "remoteChainSlug_",
        type: "uint32",
      },
      {
        internalType: "uint256",
        name: "amount_",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "minMsgGasLimit_",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "totalMsgs",
        type: "uint256",
      },
    ],
    name: "remoteAddOperationBatch",
    outputs: [],
    stateMutability: "payable",
    type: "function",
  },
];
export const getCounterContract = async (chainSlug: ChainSlug) => {
  const chainAddresses = await getAddresses(chainSlug, mode);
  if (!chainAddresses) {
    throw new Error(`addresses not found for ${chainSlug}, ${chainAddresses}`);
  }
  const counterAddress = chainAddresses["Counter"];
  if (!counterAddress) {
    throw new Error(` counter address not found for ${chainSlug}`);
  }
  return new ethers.Contract(counterAddress, Counter.abi);
};

export const getSocketContract = async (chainSlug: ChainSlug) => {
  const chainAddresses = await getAddresses(chainSlug, mode);
  if (!chainAddresses) {
    throw new Error(`addresses not found for ${chainSlug}, ${chainAddresses}`);
  }
  const socketAddress = chainAddresses.Socket;
  if (!socketAddress) {
    throw new Error(`socket address not found for ${chainSlug}`);
  }
  const provider = getProviderFromChainSlug(chainSlug);
  return new ethers.Contract(socketAddress, Socket.abi, provider);
};

export const getSocketFees = async (
  chainSlug: ChainSlug,
  siblingChainSlug: ChainSlug,
  msgGasLimit: string,
  payloadSize: number,
  executionParams: string,
  transmissionParams: string,
  plugAddress: string
) => {
  const socket = await getSocketContract(chainSlug);
  const value: BigNumber = await socket.getMinFees(
    msgGasLimit,
    payloadSize,
    executionParams,
    transmissionParams,
    siblingChainSlug,
    plugAddress
  );
  return value;
};

export const sendCounterBridgeMsg = async (
  chainSlug: ChainSlug,
  siblingSlug: ChainSlug,
  msgGasLimit: string,
  payloadSize: number,
  executionParams: string,
  transmissionParams: string
) => {
  const counter = await getCounterContract(chainSlug);
  let data = counter.interface.encodeFunctionData("remoteAddOperation", [
    siblingSlug,
    counterAddAmount,
    msgGasLimit,
    executionParams,
    transmissionParams,
  ]);
  let to = counter.address;
  const value = await getSocketFees(
    chainSlug,
    siblingSlug,
    msgGasLimit,
    payloadSize,
    executionParams,
    transmissionParams,
    to
  );

  const feesUSDValue = formatEther(value.mul(BigNumber.from(3000)));
  console.log(
    `fees for path ${chainSlug}-${siblingSlug} is ${formatEther(
      value
    )} ETH, ${feesUSDValue} USD`
  );

  const { gasLimit, gasPrice, type } = await overrides(chainSlug);
  // console.log({to, data, value, gasLimit});
  let response = await relayTx({
    to,
    data,
    value,
    gasLimit,
    gasPrice,
    type,
    chainSlug,
  });
  console.log(
    `Track message here: ${getAPIBaseURL(
      mode
    )}/messages-from-tx?srcChainSlug=${chainSlug}&srcTxHash=${response?.hash}`
  );
};

import { config as dotenvConfig } from "dotenv";
dotenvConfig();
import { BigNumber, constants } from "ethers";

import fs from "fs";
import { ethers } from "ethers";
import { Contract } from "ethers";
require("dotenv").config();
import yargs from "yargs";
import { getProviderFromChainSlug } from "../../../constants";
import SocketABI from "../../../../out/Socket.sol/Socket.json";

import path from "path";
import { mode } from "../../config/config";
import {
  CORE_CONTRACTS,
  HardhatChainName,
  hardhatChainNameToSlug,
} from "../../../../src";
import { sleep } from "@socket.tech/dl-common";

const deployedAddressPath = path.join(
  __dirname,
  `/../../../deployments/${mode}_addresses.json`
);

// batch outbound contract:
const helperContractAddress = {
  11155112: "0xF76E77186Ae85Fa0D5fce51D03e59b964fe7717A",
  11155111: "0x91C27Cad374246314E756f8Aa2f62F433d6F102C",
  80001: "0x7d96De5fa59F61457da325649bcF2B4e500055Ad",
  421613: "0x60c3A0bCEa43F5aaf8743a41351C0a7b982aE01E",
  420: "0xD21e53E568FD904c2599E41aFC2434ea11b38A2e",
  5: "0x28f26c101e3F694f1d03D477b4f34F8835141611",
};

const helperABI = [
  {
    inputs: [
      {
        internalType: "uint32",
        name: "chainSlug_",
        type: "uint32",
      },
      {
        internalType: "uint256",
        name: "amount_",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "msgGasLimit_",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "totalMsgs_",
        type: "uint256",
      },
    ],
    name: "remoteAddOperationBatch",
    outputs: [],
    stateMutability: "payable",
    type: "function",
  },
];

const WAIT_FOR_TX = false;
const totalIterations = 10;

// usage:
// npx ts-node scripts/deploy/scripts/outbound-load-test.ts --chain optimism-goerli --remoteChain arbitrum-goerli --numOfRequests 10 --waitTime 6

export const main = async () => {
  const amount = 100;
  const msgGasLimit = "100000";
  let remoteChainSlug;

  try {
    const argv = await yargs
      .option({
        chain: {
          description: "chain",
          type: "string",
          demandOption: true,
        },
      })
      .option({
        remoteChain: {
          description: "remoteChain",
          type: "string",
          demandOption: true,
        },
      })
      .option({
        numOfRequests: {
          description: "numOfRequests",
          type: "number",
          demandOption: true,
        },
      })
      .option({
        waitTime: {
          description: "waitTime",
          type: "number",
          demandOption: false,
        },
      }).argv;

    const chain = argv.chain as HardhatChainName;
    const chainSlug = hardhatChainNameToSlug[chain];

    const providerInstance = getProviderFromChainSlug(chainSlug);

    const signer = new ethers.Wallet(
      process.env.SOCKET_SIGNER_KEY as string,
      providerInstance
    );

    const remoteChain = argv.remoteChain as HardhatChainName;
    remoteChainSlug = hardhatChainNameToSlug[remoteChain];

    const numOfRequests = argv.numOfRequests as number;
    const waitTime = argv.waitTime as number;

    const config: any = JSON.parse(
      fs.readFileSync(deployedAddressPath, "utf-8")
    );

    const counterAddress = config[chainSlug]["Counter"];

    const helper: Contract = new ethers.Contract(
      helperContractAddress[chainSlug],
      helperABI,
      signer
    );

    const socket: Contract = new ethers.Contract(
      config[chainSlug][CORE_CONTRACTS.Socket],
      SocketABI.abi,
      signer
    );

    const value = await socket.getMinFees(
      msgGasLimit,
      100, // payload size
      constants.HashZero,
      constants.HashZero,
      remoteChainSlug,
      counterAddress
    );

    if (WAIT_FOR_TX) {
      await confirmAndWait(
        signer,
        helper,
        remoteChainSlug,
        amount,
        msgGasLimit,
        numOfRequests,
        value,
        waitTime,
        chainSlug
      );
    } else {
      await sendAndWait(
        signer,
        helper,
        remoteChainSlug,
        amount,
        msgGasLimit,
        numOfRequests,
        value,
        waitTime,
        chainSlug
      );
    }
  } catch (error) {
    console.log(
      `Error while sending remoteAddOperation with ${amount} amount and ${msgGasLimit} gas limit to counter at ${remoteChainSlug}`
    );
    console.error("Error while sending transaction", error);
    throw error;
  }
};

const sendAndWait = async (
  signer,
  helper,
  remoteChainSlug,
  amount,
  msgGasLimit,
  numOfRequests,
  value,
  waitTime,
  chainSlug
) => {
  const nonce = await signer.getTransactionCount();

  for (let index = 0; index < totalIterations; index++) {
    const tx = await helper
      .connect(signer)
      .remoteAddOperationBatch(
        remoteChainSlug,
        amount,
        msgGasLimit,
        numOfRequests,
        {
          value: BigNumber.from(value).mul(numOfRequests),
          nonce: nonce + index,
        }
      );

    console.log(
      `remoteAddOperation-tx with hash: ${
        tx.hash
      } was sent with ${amount} amount and ${msgGasLimit} gas limit to counter at ${remoteChainSlug}, value: ${
        value * numOfRequests
      }`
    );
    console.log(
      `Track here: https://6il289myzb.execute-api.us-east-1.amazonaws.com/dev/messages-from-tx?srcChainSlug=${chainSlug}&srcTxHash=${tx.hash
        .toString()
        .toLowerCase()}`
    );

    if (waitTime && waitTime > 0) {
      await sleep(waitTime);
    }
  }
};

const confirmAndWait = async (
  signer,
  helper,
  remoteChainSlug,
  amount,
  msgGasLimit,
  numOfRequests,
  value,
  waitTime,
  chainSlug
) => {
  for (let i = 0; i < totalIterations; i++) {
    const tx = await helper
      .connect(signer)
      .remoteAddOperationBatch(
        remoteChainSlug,
        amount,
        msgGasLimit,
        numOfRequests,
        {
          value: BigNumber.from(value).mul(numOfRequests),
        }
      );

    await tx.wait();
    console.log(
      `remoteAddOperation-tx with hash: ${
        tx.hash
      } was sent with ${amount} amount and ${msgGasLimit} gas limit to counter at ${remoteChainSlug}, value: ${
        value * numOfRequests
      }`
    );
    console.log(
      `Track here: https://6il289myzb.execute-api.us-east-1.amazonaws.com/dev/messages-from-tx?srcChainSlug=${chainSlug}&srcTxHash=${tx.hash
        .toString()
        .toLowerCase()}`
    );

    if (waitTime && waitTime > 0) {
      await sleep(waitTime);
    }
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

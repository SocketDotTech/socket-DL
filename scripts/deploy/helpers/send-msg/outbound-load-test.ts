import { config as dotenvConfig } from "dotenv";
import { BigNumber, constants } from "ethers";
dotenvConfig();

import { Contract, ethers } from "ethers";
import fs from "fs";
import yargs from "yargs";
import { getProviderFromChainSlug } from "../../../constants";
require("dotenv").config();

import { sleep } from "@socket.tech/dl-common";
import { ChainSlug } from "@socket.tech/dl-core";
import { formatEther } from "ethers/lib/utils";
import path from "path";
import { HardhatChainName, hardhatChainNameToSlug } from "../../../../src";
import { mode } from "../../config/config";
import { getAPIBaseURL } from "../../utils";
import { LoadTestHelperABI, getSocketFees } from "./utils";

const deployedAddressPath = path.join(
  __dirname,
  `/../../../../deployments/${mode}_addresses.json`
);

// batch outbound contract:
const helperContractAddress = {
  [ChainSlug.ARBITRUM_SEPOLIA]: "0xd206accf23905ac3325d2614981f79657923dbfe",
  [ChainSlug.OPTIMISM_SEPOLIA]: "0xa57d28c0fd64a3b82f3f9b5a2ce65c46d1483884",
  [ChainSlug.ARBITRUM]: "0x19ff5eb35bbf1525b29ae96167b0c94ac5387ded",
};

const payload =
  "0xbad314e77c9e165fb6cdad2b69ae15ea10f47a976480a84ea0ef9a8b8817b997000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000";

const WAIT_FOR_TX = true;
const totalIterations = 10;

// usage:
// time npx ts-node scripts/deploy/helpers/send-msg/outbound-load-test.ts --chain arbitrum_sepolia --remoteChain optimism_sepolia --numOfRequests 10 --waitTimeSecs 4

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
        waitTimeSecs: {
          description: "waitTimeSecs",
          type: "number",
          demandOption: false,
        },
      }).argv;

    const chain = argv.chain as HardhatChainName;
    const chainSlug = hardhatChainNameToSlug[chain];
    const providerInstance = getProviderFromChainSlug(chainSlug);

    if (!process.env.LOAD_TEST_PRIVATE_KEY) {
      console.error("LOAD_TEST_PRIVATE_KEY not found in env");
      return;
    }
    const signer = new ethers.Wallet(
      process.env.LOAD_TEST_PRIVATE_KEY as string,
      providerInstance
    );
    console.log("signer address : ", signer.address);
    console.log(
      "signer balance on chain ",
      chainSlug,
      " is ",
      formatEther(await signer.getBalance())
    );
    const remoteChain = argv.remoteChain as HardhatChainName;
    remoteChainSlug = hardhatChainNameToSlug[remoteChain];
    const numOfRequests = argv.numOfRequests as number;
    const waitTimeSecs = argv.waitTimeSecs as number;

    const config: any = JSON.parse(
      fs.readFileSync(deployedAddressPath, "utf-8")
    );

    const counterAddress = config[chainSlug]["Counter"];
    if (!helperContractAddress[chainSlug]) {
      console.log("helperContractAddress not found for ", chainSlug);
      return;
    }
    const helper: Contract = new ethers.Contract(
      helperContractAddress[chainSlug],
      LoadTestHelperABI,
      signer
    );

    const value = await getSocketFees(
      chainSlug,
      remoteChainSlug,
      msgGasLimit,
      payload.length,
      constants.HashZero,
      constants.HashZero,
      counterAddress
    );
    await sendTx(
      counterAddress,
      signer,
      helper,
      remoteChainSlug,
      amount,
      msgGasLimit,
      numOfRequests,
      value,
      waitTimeSecs,
      chainSlug,
      WAIT_FOR_TX
    );
  } catch (error) {
    console.log(
      `Error while sending remoteAddOperation with ${amount} amount and ${msgGasLimit} gas limit to counter at ${remoteChainSlug}`
    );
    console.error("Error while sending transaction", error);
    throw error;
  }
};

const sendTx = async (
  counterAddress: string,
  signer,
  helper,
  remoteChainSlug,
  amount,
  msgGasLimit,
  numOfRequests,
  value,
  waitTimeSecs,
  chainSlug,
  waitForConfirmation: boolean
) => {
  const nonce = await signer.getTransactionCount();
  console.log(
    "total value: ",
    formatEther(BigNumber.from(value).mul(numOfRequests))
  );

  for (let index = 0; index < totalIterations; index++) {
    console.log("========= starting iteration: ", index, " =========");
    const start = Date.now();
    const tx = await helper
      .connect(signer)
      .remoteAddOperationBatch(
        counterAddress,
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
      } in ${Date.now() - start} ms`
    );
    console.log(
      `Track here: ${getAPIBaseURL(
        mode
      )}/messages-from-tx?srcChainSlug=${chainSlug}&srcTxHash=${tx?.hash}`
    );

    if (waitForConfirmation) {
      await tx.wait();
      console.log(`remoteAddOperation-tx with hash: ${tx.hash} confirmed`);
    }
    if (waitTimeSecs && waitTimeSecs > 0) {
      console.log("waiting for ", waitTimeSecs, " secs...");
      await sleep(waitTimeSecs * 1000);
    }
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

// Outbound load contract

// pragma solidity 0.8.19;

// interface ICounter {
//     function remoteAddOperation(
//         uint32 chainSlug_,
//         uint256 amount_,
//         uint256 minMsgGasLimit_,
//         bytes32 executionParams_,
//         bytes32 transmissionParams_
//     ) external payable;
// }

// contract OutboundLoadTest {
//     ICounter counter__;

//     constructor() {}

//     function remoteAddOperationBatch(
//         address counter_,
//         uint32 remoteChainSlug_,
//         uint256 amount_,
//         uint256 minMsgGasLimit_,
//         uint256 totalMsgs
//     ) external payable {
//         counter__ = ICounter(counter_);
//         for (uint256 i = 0; i < totalMsgs; i++) {
//             counter__.remoteAddOperation{value: msg.value / totalMsgs}(
//                 remoteChainSlug_,
//                 amount_,
//                 minMsgGasLimit_,
//                 bytes32(0),
//                 bytes32(0)
//             );
//         }
//     }
// }

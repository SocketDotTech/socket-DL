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
  11155112: "0xF76E77186Ae85Fa0D5fce51D03e59b964fe7717A",
  11155111: "0x91C27Cad374246314E756f8Aa2f62F433d6F102C",
  [ChainSlug.ARBITRUM_SEPOLIA]: "0x2c3E3Ff54d82cA96BBB2F4529bee114eB200e3F0",
  [ChainSlug.OPTIMISM_SEPOLIA]: "0x4B882c8A1009c0a4fd80151FEb6d1a3656C49C9a",
};

const payload =
  "0xbad314e77c9e165fb6cdad2b69ae15ea10f47a976480a84ea0ef9a8b8817b997000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000";

const WAIT_FOR_TX = true;
const totalIterations = 10;

// usage:
// npx ts-node scripts/deploy/helpers/send-msg/outbound-load-test.ts --chain arbitrum_sepolia --remoteChain optimism_sepolia --numOfRequests 10 --waitTime 6

export const main = async () => {
  const amount = 100;
  const msgGasLimit = "0";
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
    const waitTime = argv.waitTime as number;

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
      signer,
      helper,
      remoteChainSlug,
      amount,
      msgGasLimit,
      numOfRequests,
      value,
      waitTime,
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
  signer,
  helper,
  remoteChainSlug,
  amount,
  msgGasLimit,
  numOfRequests,
  value,
  waitTime,
  chainSlug,
  waitForConfirmation: boolean
) => {
  const nonce = await signer.getTransactionCount();
  console.log(
    "total value: ",
    formatEther(BigNumber.from(value).mul(numOfRequests))
  );

  for (let index = 0; index < totalIterations; index++) {
    const tx = await helper
      .connect(signer)
      .remoteAddOperationBatch(
        remoteChainSlug,
        amount,
        msgGasLimit,
        numOfRequests,
        payload,
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
      `Track here: ${getAPIBaseURL(
        mode
      )}/messages-from-tx?srcChainSlug=${chainSlug}&srcTxHash=${tx?.hash}`
    );

    if (waitForConfirmation) {
      await tx.wait();
      console.log(`remoteAddOperation-tx with hash: ${tx.hash} confirmed`);
    }
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

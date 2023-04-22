import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import fs from "fs";
import { ethers } from "ethers";
import { Contract } from "ethers";
require("dotenv").config();
import yargs from "yargs";
import { chainSlugs, DeploymentMode, getProviderFromChainName } from "../../constants";
import CounterABI from "@socket.tech/dl-core/artifacts/abi/Counter.json";

// import * as CounterABI from "../../../artifacts/contracts/examples/Counter.sol/Counter.json";
import path from "path";

const mode = process.env.DEPLOYMENT_MODE as DeploymentMode | DeploymentMode.DEV;
const deployedAddressPath = path.join(
  __dirname,
  `/../../../deployments/${mode}_addresses.json`
);

// npx ts-node scripts/deploy/scripts/outbound-load-test.ts --chain polygon-mumbai --remoteChain optimism-goerli --numOfRequests 10 --waitTime 100

// usage:
// npx ts-node scripts/deploy/scripts/outbound-load-test.ts --chain optimism --remoteChain polygon-mainnet --numOfRequests 50 --waitTime 100
export const main = async () => {
  const amount = 100;
  const msgGasLimit = "100000";
  const gasLimit = 185766;

  // 0.00003

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

    const chain = argv.chain as keyof typeof chainSlugs;
    const chainSlug = chainSlugs[chain];

    const providerInstance = getProviderFromChainName(chain);

    const signer = new ethers.Wallet(
      process.env.LOAD_TEST_PRIVATE_KEY as string,
      providerInstance
    );

    const remoteChain = argv.remoteChain as keyof typeof chainSlugs;
    remoteChainSlug = chainSlugs[remoteChain];

    const numOfRequests = argv.numOfRequests as number;
    const waitTime = argv.waitTime as number;

    const config: any = JSON.parse(
      fs.readFileSync(deployedAddressPath, "utf-8")
    );

    // const counterAddress = config[chainSlug]["Counter"];
    const counterAddress = "0xefc0c02abca8dda7d2b399d5c41358cc8ff0a183";

    const counter: Contract = new ethers.Contract(
      counterAddress,
      CounterABI,
      signer
    );

    for (let i = 0; i < numOfRequests; i++) {
      const tx = await counter
        .connect(signer)
        .remoteAddOperation(remoteChainSlug, amount, msgGasLimit, {
          gasLimit,
          value: ethers.utils.parseUnits("30000", "gwei").toNumber(),
        });

      
      console.log()

      // await tx.wait();

      console.log(
        `remoteAddOperation-tx with hash: ${JSON.stringify(
          tx.hash
        )} was sent with ${amount} amount and ${msgGasLimit} gas limit to counter at ${remoteChainSlug}`
      );

      return;
      // if (waitTime && waitTime > 0) {
      //   await sleep(waitTime);
      // }
    }
  } catch (error) {
    console.log(
      `Error while sending remoteAddOperation with ${amount} amount and ${msgGasLimit} gas limit to counter at ${remoteChainSlug}`
    );
    console.error("Error while sending transaction", error);
    throw error;
  }
};

const sleep = (delay: any) =>
  new Promise((resolve) => setTimeout(resolve, delay));

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

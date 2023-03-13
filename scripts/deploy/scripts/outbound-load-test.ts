import fs from "fs";
import { BigNumber, ethers } from "ethers";
import { Contract } from "ethers";
require("dotenv").config();
import yargs from "yargs";
import { chainIds, getProviderFromChainName } from "../../constants";
import * as CounterABI from "../../../artifacts/contracts/examples/Counter.sol/Counter.json";
import path from "path";

const deployedAddressPath = path.join(
  __dirname,
  "/../../../deployments/addresses.json"
);

// usage:
// npx ts-node scripts/deploy/scripts/outbound-load-test.ts --chain polygon-mumbai --remoteChain goerli --load 5 --waitTime 10
export const main = async () => {
  const amount = 100;
  const msgGasLimit = "19000000";
  const gasLimit = 200485;
  const fees = "20000000000000000";
  let remoteChainId;

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
        load: {
          description: "load",
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

    const chain = argv.chain as keyof typeof chainIds;
    const chainId = chainIds[chain];

    const providerInstance = getProviderFromChainName(chain);

    const signer = new ethers.Wallet(
      process.env.LOAD_TEST_PRIVATE_KEY as string,
      providerInstance
    );

    const remoteChain = argv.remoteChain as keyof typeof chainIds;
    remoteChainId = chainIds[remoteChain];

    const load = argv.load as number;
    const waitTime = argv.waitTime as number;

    const config: any = JSON.parse(
      fs.readFileSync(deployedAddressPath, "utf-8")
    );

    const counterAddress = config[chainId]["Counter"];

    const counter: Contract = new ethers.Contract(
      counterAddress,
      CounterABI.abi,
      signer
    );

    for (let i = 0; i < load; i++) {
      const tx = await counter
        .connect(signer)
        .remoteAddOperation(remoteChainId, amount, msgGasLimit, {
          gasLimit,
          value: BigNumber.from(fees),
        });

      await tx.wait();

      console.log(
        `remoteAddOperation-tx with hash: ${JSON.stringify(
          tx.hash
        )} was sent with ${amount} amount and ${msgGasLimit} gas limit to counter at ${remoteChainId}`
      );

      if (waitTime && waitTime > 0) {
        await sleep(waitTime);
      }
    }
  } catch (error) {
    console.log(
      `Error while sending remoteAddOperation with ${amount} amount and ${msgGasLimit} gas limit to counter at ${remoteChainId}`
    );
    console.error("Error while sending transaction", error);
    throw error;
  }
};

const sleep = (delay: any) =>
  new Promise((resolve) => setTimeout(resolve, delay * 1000));

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

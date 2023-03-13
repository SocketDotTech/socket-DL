import fs from "fs";
import { ethers } from "ethers";
import { Contract } from "ethers";
import { deployedAddressPath, sleep } from "../utils";
require("dotenv").config();
import yargs from "yargs";
import { chainIds, getProviderFromChainName } from "../../constants";
import * as CounterABI from "../../../artifacts/contracts/examples/Counter.sol/Counter.json";

// usage:
// npx ts-node scripts/deploy/scripts/outbound-load-test.ts --chain 80001 --remoteChain 5 --load 10 --waithTime 50
export const main = async () => {
  try {
    const amount = 100;
    const msgGasLimit = "19000000";
    const gasLimit = 200485;
    const fees = 20000000000000000;

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
          type: "number",
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
          demandOption: true,
        },
      }).argv;

    const chain = argv.chain as keyof typeof chainIds;

    const providerInstance = getProviderFromChainName(chain);

    const chainId = chainIds[chain];

    const config: any = JSON.parse(
      fs.readFileSync(deployedAddressPath, "utf-8")
    );

    const signer = new ethers.Wallet(
      process.env.LOAD_TEST_PRIVATE_KEY as string,
      providerInstance
    );

    const counterAddress = config[chainId]["Counter"];

    console.log(`counterAddress is: ${counterAddress}`);

    const counter: Contract = new ethers.Contract(
      counterAddress,
      CounterABI.abi,
      signer
    );

    const load = argv.load as number;
    const remoteChainId = argv.remoteChain as number;

    for (let i = 0; i < load; i++) {
      await counter
        .connect(signer)
        .remoteAddOperation(remoteChainId, amount, msgGasLimit, {
          gasLimit,
          value: fees,
        });

      const waitTime = argv.waitTime as number;

      await sleep(waitTime);
    }

    console.log(
      `Sent remoteAddOperation with ${amount} amount and ${msgGasLimit} gas limit to counter at ${remoteChainId}`
    );
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

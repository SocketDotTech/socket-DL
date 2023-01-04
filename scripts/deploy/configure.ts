import hre from "hardhat";
import { Contract } from "ethers";
import { chainIds } from "../constants";
import { config } from "./config";
import {
  getInstance,
  getSigners,
  setupConfig
} from "./utils";

export const main = async () => {
  try {
    for (let chain in config) {
      console.log(`Deploying configs for ${chain}`)
      const chainSetups = config[chain];

      await hre.changeNetwork(chain);
      const { socketSigner, counterSigner } = await getSigners();

      for (let index = 0; index < chainSetups.length; index++) {
        let remoteChain = chainSetups[index]["remoteChain"];
        let config = chainSetups[index]["config"]

        if (chain === remoteChain) throw new Error("Wrong chains");

        // deploy contracts for different configurations
        let counters;
        for (let index = 0; index < config.length; index++) {
          console.log(`Setting up ${config[index]} for ${remoteChain}`)
          counters = await setupConfig(config[index], chain, remoteChain, socketSigner);
        }

        // add a config to plugs on local and remote
        const counter: Contract = await getInstance(
          "Counter",
          counters.localCounter
        );

        const tx = await counter
          .connect(counterSigner)
          .setSocketConfig(
            chainIds[remoteChain],
            counters.remoteCounter,
            chainSetups[index]["configForCounter"]
          );

        console.log(
          `Setting config ${chainSetups[index]["configForCounter"]} for ${chainIds[remoteChain]} chain id! Transaction Hash: ${tx.hash}`
        );
        await tx.wait();
      }
    }
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

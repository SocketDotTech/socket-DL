import { Contract } from "ethers";
import { chainIds } from "../constants";
import { config } from "./config";
import {
  getInstance,
  getChainId,
  getSigners,
  setupConfig
} from "./utils";

const localChain = "";

export const main = async () => {
  try {
    const chainSetups = config[localChain];
    const chainId = await getChainId();
    const { socketSigner, counterSigner } = await getSigners();

    if (chainId !== chainIds[localChain])
      throw new Error("Wrong network connected");
    if (chainSetups.length === 0) throw new Error("No config found");

    for (let index = 0; index < chainSetups.length; index++) {
      let remoteChain = chainSetups[index]["remoteChain"];
      let config = chainSetups[index]["config"]

      if (localChain === remoteChain) throw new Error("Wrong chains");
      if (config.length === 0 && chainSetups[index]["configForCounter"] === "")
        throw new Error("No configuration provided");

      // deploy contracts for different configurations
      let counters;
      for (let index = 0; index < config.length; index++) {
        counters = await setupConfig(config[index], localChain, remoteChain, socketSigner);
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
      await tx.wait();
      console.log(
        `Set config ${chainSetups[index]["configForCounter"]} for ${chainIds[remoteChain]} chain id!`
      );
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

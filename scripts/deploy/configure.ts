import fs from "fs";
import hre from "hardhat";
import { Contract } from "ethers";
import { chainIds } from "../constants";
import { config } from "./config";
import {
  deployedAddressPath,
  getInstance,
  getSigners,
  getSwitchboardAddress
} from "./utils";
import deployAndRegisterSwitchboard from "./deployAndRegisterSwitchboard";

const capacitorType = 1

export const main = async () => {
  try {
    if (!fs.existsSync(deployedAddressPath)) {
      throw new Error("addresses.json not found");
    }

    for (let chain in config) {
      console.log(`Deploying configs for ${chain}`)
      const chainSetups = config[chain];

      await hre.changeNetwork(chain);
      const { socketSigner, counterSigner } = await getSigners();

      for (let index = 0; index < chainSetups.length; index++) {
        const { remoteChain, remoteConfig, localConfig } = validateChainSetup(chain, chainSetups[index]);

        const integrations = chainSetups[index]["config"]
        let localConfigUpdated = localConfig

        // deploy contracts for different configurations
        for (let index = 0; index < integrations.length; index++) {
          console.log(`Setting up ${integrations[index]} for ${remoteChain}`)
          localConfigUpdated = await deployAndRegisterSwitchboard(integrations[index], chain, capacitorType, remoteChain, socketSigner, localConfigUpdated)
          console.log("Done! 🚀")
        }

        await setSocketConfig(chainIds[remoteChain], chainSetups[index]["configForCounter"], localConfigUpdated, remoteConfig, counterSigner)
      }
    }
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

const validateChainSetup = (chain, chainSetups) => {
  let remoteChain = chainSetups["remoteChain"];
  if (chain === remoteChain) throw new Error("Wrong chains");

  const addresses = JSON.parse(fs.readFileSync(deployedAddressPath, "utf-8"));
  if (!addresses[chainIds[chain]] || !addresses[chainIds[remoteChain]]) {
    throw new Error("Deployed Addresses not found");
  }

  let remoteConfig = addresses[chainIds[remoteChain]];
  let localConfig = addresses[chainIds[chain]];

  return { remoteChain, remoteConfig, localConfig };
}

const setSocketConfig = async (remoteChainSlug, integrationType, localConfig, remoteConfig, counterSigner) => {
  // add a config to plugs on local and remote
  const counter: Contract = await getInstance(
    "Counter",
    localConfig["Counter"]
  );

  const tx = await counter
    .connect(counterSigner)
    .setSocketConfig(
      remoteChainSlug,
      remoteConfig["Counter"],
      getSwitchboardAddress(remoteChainSlug, integrationType, localConfig)
    );

  console.log(
    `Setting config ${integrationType} for ${remoteChainSlug} chain id! Transaction Hash: ${tx.hash}`
  );
  await tx.wait();
}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

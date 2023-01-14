import fs from "fs";
import hre from "hardhat";
import { constants, Contract } from "ethers";
import { chainIds, networkToChainId, switchboards } from "../constants";
import { config } from "./config";
import {
  deployedAddressPath,
  getInstance,
  getSigners,
  getSwitchboardAddress
} from "./utils";
import deployAndRegisterSwitchboard from "./deployAndRegisterSwitchboard";
import { deploymentAddresses, IntegrationTypes, NativeSwitchboard } from "../../src";

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

    await setRemoteSwitchboards();
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

const setRemoteSwitchboards = async () => {
  try {
    for (let srcChain in deploymentAddresses) {
      await hre.changeNetwork(networkToChainId[srcChain]);
      const { socketSigner } = await getSigners();

      for (let dstChain in deploymentAddresses[srcChain]?.["integrations"]) {
        const dstConfig = deploymentAddresses[srcChain]["integrations"][dstChain]

        if (dstConfig?.[IntegrationTypes.nativeIntegration]) {
          const srcSwitchboardType = switchboards[networkToChainId[srcChain]]?.[networkToChainId[dstChain]]?.["switchboard"]
          const dstSwitchboardAddress = getSwitchboardAddress(srcChain, IntegrationTypes.nativeIntegration, deploymentAddresses?.[dstChain])
          if (!dstSwitchboardAddress) continue;

          const srcSwitchboardAddress = dstConfig?.[IntegrationTypes.nativeIntegration]["switchboard"];

          let functionName, sbContract;
          if (srcSwitchboardType === NativeSwitchboard.POLYGON_L1) {
            sbContract = await getInstance("PolygonL1Switchboard", srcSwitchboardAddress)

            const fxChild = await sbContract.fxChildTunnel();
            if (fxChild !== constants.AddressZero) continue;

            functionName = "setFxChildTunnel"
            console.log(`Setting ${dstSwitchboardAddress} fx child tunnel in ${srcSwitchboardAddress} on networks ${srcChain}-${dstChain}`)
          } else if (srcSwitchboardType === NativeSwitchboard.POLYGON_L2) {
            sbContract = await getInstance("PolygonL2Switchboard", srcSwitchboardAddress)

            const fxRoot = await sbContract.fxRootTunnel();
            if (fxRoot !== constants.AddressZero) continue;

            functionName = "setFxRootTunnel"
            console.log(`Setting ${dstSwitchboardAddress} fx root tunnel in ${srcSwitchboardAddress} on networks ${srcChain}-${dstChain}`)
          } else {
            sbContract = await getInstance("ArbitrumL1Switchboard", srcSwitchboardAddress)

            const remoteNativeSwitchboard = await sbContract.remoteNativeSwitchboard();
            if (remoteNativeSwitchboard.toLowerCase() === dstSwitchboardAddress.toLowerCase()) continue;

            functionName = "updateRemoteNativeSwitchboard"
            console.log(`Setting ${dstSwitchboardAddress} remote switchboard in ${srcSwitchboardAddress} on networks ${srcChain}-${dstChain}`)
          }

          const tx = await sbContract.connect(socketSigner)[functionName](dstSwitchboardAddress);
          console.log(tx.hash);
          await tx.wait();

        }
      }
    }
  } catch (error) {
    console.error(error);
  }
}

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

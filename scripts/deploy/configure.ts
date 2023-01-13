import fs from "fs";
import hre from "hardhat";
import { Contract } from "ethers";
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

          if (srcSwitchboardType === NativeSwitchboard.POLYGON_L1) {
            const sbContract = await getInstance("PolygonL1Switchboard", dstConfig?.[IntegrationTypes.nativeIntegration]["switchboard"])
            const tx = await sbContract.connect(socketSigner).setFxChildTunnel(dstSwitchboardAddress);
            console.log(`Setting ${dstSwitchboardAddress} fx child tunnel in ${sbContract.address} on networks ${srcChain}-${dstChain}: ${tx.hash}`)
            await tx.wait();
          } else if (srcSwitchboardType === NativeSwitchboard.POLYGON_L2) {
            const sbContract = await getInstance("PolygonL2Switchboard", dstConfig?.[IntegrationTypes.nativeIntegration]["switchboard"])
            const tx = await sbContract.connect(socketSigner).setFxRootTunnel(dstSwitchboardAddress);
            console.log(`Setting ${dstSwitchboardAddress} fx root tunnel in ${sbContract.address} on networks ${srcChain}-${dstChain}: ${tx.hash}`)
            await tx.wait();
          } else {
            const sbContract = await getInstance("ArbitrumL1Switchboard", dstConfig?.[IntegrationTypes.nativeIntegration]["switchboard"])
            const tx = await sbContract.connect(socketSigner).updateRemoteNativeSwitchboard(dstSwitchboardAddress);
            console.log(`Setting ${dstSwitchboardAddress} remote switchboard in ${sbContract.address} on networks ${srcChain}-${dstChain}: ${tx.hash}`)
            await tx.wait();
          }
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

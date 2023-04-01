import fs from "fs";
import hre from "hardhat";
import { constants, Contract } from "ethers";
import {
  chainSlugs,
  networkToChainSlug,
  proposeGasLimit,
  switchboards,
  transmitterAddress,
} from "../constants";
import { config } from "./config";
import {
  deployedAddressPath,
  getInstance,
  getSigners,
  getSwitchboardAddress,
} from "./utils";
import deployAndRegisterSwitchboard from "./deployAndRegisterSwitchboard";
import {
  deploymentAddresses,
  IntegrationTypes,
  NativeSwitchboard,
} from "../../src";

const capacitorType = 1;

export const main = async () => {
  try {
    if (!fs.existsSync(deployedAddressPath)) {
      throw new Error("addresses.json not found");
    }
    let addresses = JSON.parse(fs.readFileSync(deployedAddressPath, "utf-8"));

    for (let chain in config) {
      console.log(`Deploying configs for ${chain}`);
      const chainSetups = config[chain];

      await hre.changeNetwork(chain);
      const { socketSigner, counterSigner } = await getSigners();

      for (let index = 0; index < chainSetups.length; index++) {
        const { remoteChain, remoteConfig, localConfig } = validateChainSetup(
          addresses,
          chain,
          chainSetups[index]
        );

        const integrations = chainSetups[index]["config"];
        let localConfigUpdated = localConfig;

        // deploy contracts for different configurations
        for (let index = 0; index < integrations.length; index++) {
          console.log(`Setting up ${integrations[index]} for ${remoteChain}`);
          localConfigUpdated = await deployAndRegisterSwitchboard(
            integrations[index],
            chain,
            capacitorType,
            remoteChain,
            socketSigner,
            localConfigUpdated
          );
          addresses[chainSlugs[chain]] = localConfigUpdated;
          console.log("Done! 🚀");
        }

        await configTransmitter(
          transmitterAddress[chain],
          remoteChain,
          localConfigUpdated,
          socketSigner
        );

        const socket = await getInstance(
          "Socket",
          localConfigUpdated["Socket"]
        );

        if (remoteConfig["Counter"])
          await setSocketConfig(
            socket,
            chainSlugs[remoteChain],
            remoteConfig["Counter"],
            chainSetups[index]["configForCounter"],
            localConfigUpdated,
            counterSigner
          );
      }
    }

    await setRemoteSwitchboards(addresses);
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

const setRemoteSwitchboards = async (addresses) => {
  try {
    for (let srcChain in addresses) {
      await hre.changeNetwork(networkToChainSlug[srcChain]);
      const { socketSigner } = await getSigners();

      for (let dstChain in addresses[srcChain]?.["integrations"]) {
        const dstConfig = addresses[srcChain]["integrations"][dstChain];

        if (dstConfig?.[IntegrationTypes.native]) {
          const srcSwitchboardType =
            switchboards[networkToChainSlug[srcChain]]?.[
              networkToChainSlug[dstChain]
            ]?.["switchboard"];
          const dstSwitchboardAddress = getSwitchboardAddress(
            srcChain,
            IntegrationTypes.native,
            deploymentAddresses?.[dstChain]
          );
          if (!dstSwitchboardAddress) continue;

          const srcSwitchboardAddress =
            dstConfig?.[IntegrationTypes.native]["switchboard"];

          let functionName, sbContract;
          if (srcSwitchboardType === NativeSwitchboard.POLYGON_L1) {
            sbContract = await getInstance(
              "PolygonL1Switchboard",
              srcSwitchboardAddress
            );

            const fxChild = await sbContract.fxChildTunnel();
            if (fxChild !== constants.AddressZero) continue;

            functionName = "setFxChildTunnel";
            console.log(
              `Setting ${dstSwitchboardAddress} fx child tunnel in ${srcSwitchboardAddress} on networks ${srcChain}-${dstChain}`
            );
          } else if (srcSwitchboardType === NativeSwitchboard.POLYGON_L2) {
            sbContract = await getInstance(
              "PolygonL2Switchboard",
              srcSwitchboardAddress
            );

            const fxRoot = await sbContract.fxRootTunnel();
            if (fxRoot !== constants.AddressZero) continue;

            functionName = "setFxRootTunnel";
            console.log(
              `Setting ${dstSwitchboardAddress} fx root tunnel in ${srcSwitchboardAddress} on networks ${srcChain}-${dstChain}`
            );
          } else {
            sbContract = await getInstance(
              "ArbitrumL1Switchboard",
              srcSwitchboardAddress
            );

            const remoteNativeSwitchboard =
              await sbContract.remoteNativeSwitchboard();
            if (
              remoteNativeSwitchboard.toLowerCase() ===
              dstSwitchboardAddress.toLowerCase()
            )
              continue;

            functionName = "updateRemoteNativeSwitchboard";
            console.log(
              `Setting ${dstSwitchboardAddress} remote switchboard in ${srcSwitchboardAddress} on networks ${srcChain}-${dstChain}`
            );
          }

          const tx = await sbContract
            .connect(socketSigner)
            [functionName](dstSwitchboardAddress);
          console.log(tx.hash);
          await tx.wait();
        }
      }
    }
  } catch (error) {
    console.error(error);
  }
};

const validateChainSetup = (addresses, chain, chainSetups) => {
  let remoteChain = chainSetups["remoteChain"];
  if (chain === remoteChain) throw new Error("Wrong chains");

  if (!addresses[chainSlugs[chain]] || !addresses[chainSlugs[remoteChain]]) {
    throw new Error("Deployed Addresses not found");
  }

  let remoteConfig = addresses[chainSlugs[remoteChain]];
  let localConfig = addresses[chainSlugs[chain]];

  return { remoteChain, remoteConfig, localConfig };
};

const setSocketConfig = async (
  socket,
  remoteChainSlug,
  remoteCounter,
  integrationType,
  localConfig,
  counterSigner
) => {
  // add a config to plugs on local and remote
  const counter: Contract = await getInstance(
    "Counter",
    localConfig["Counter"]
  );

  const switchboard = getSwitchboardAddress(
    remoteChainSlug,
    integrationType,
    localConfig
  );
  const configs = await socket.getPlugConfig(counter.address, remoteChainSlug);
  if (
    configs["siblingPlug"].toLowerCase() === remoteCounter.toLowerCase() &&
    configs["inboundSwitchboard__"].toLowerCase() === switchboard.toLowerCase()
  )
    return;

  const tx = await counter
    .connect(counterSigner)
    .setSocketConfig(remoteChainSlug, remoteCounter, switchboard);

  console.log(
    `Setting config ${integrationType} for ${remoteChainSlug} chain id! Transaction Hash: ${tx.hash}`
  );
  await tx.wait();
};

const configTransmitter = async (
  transmitter,
  remoteChain,
  localConfig,
  signer
) => {
  const transmitManager: Contract = await getInstance(
    "TransmitManager",
    localConfig["TransmitManager"]
  );
  const remoteChainSlug = chainSlugs[remoteChain];

  const isSet = await transmitManager.isTransmitter(
    transmitter,
    remoteChainSlug
  );
  if (!isSet) {
    const tx = await transmitManager
      .connect(signer)
      .grantTransmitterRole(remoteChainSlug, transmitter);

    console.log(
      `Setting transmitter ${transmitter} for ${remoteChainSlug} chain id! Transaction Hash: ${tx.hash}`
    );
    await tx.wait();
  }

  const gasLimit = await transmitManager.proposeGasLimit(remoteChainSlug);
  if (parseInt(gasLimit) !== proposeGasLimit[remoteChain]) {
    const tx = await transmitManager
      .connect(signer)
      .setProposeGasLimit(remoteChainSlug, proposeGasLimit[remoteChain]);

    console.log(
      `Setting propose gas limit ${proposeGasLimit[remoteChain]} for ${remoteChainSlug} chain id! Transaction Hash: ${tx.hash}`
    );
    await tx.wait();
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

import fs from "fs";
import hre from "hardhat";
import { constants } from "ethers";
import {
  attestGasLimit,
  executionOverhead,
  networkToChainSlug,
  proposeGasLimit,
  switchboards,
} from "../constants";
import {
  deployedAddressPath,
  getInstance,
  getSigners,
  getSwitchboardAddress,
  storeAddresses,
} from "./utils";
import {
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  IntegrationTypes,
  MainnetIds,
  NativeSwitchboard,
  TestnetIds,
  isTestnet,
} from "../../src";
import registerSwitchBoard from "./scripts/registerSwitchboard";
import { setProposeGasLimit } from "../limits-updater/set-propose-gaslimit";
import { setAttestGasLimit } from "../limits-updater/set-attest-gaslimit";
import { setExecutionOverhead } from "../limits-updater/set-execution-overhead";

const capacitorType = 1;
const maxPacketLength = 10;
let chains = [...TestnetIds, ...MainnetIds];

export const main = async () => {
  try {
    if (!fs.existsSync(deployedAddressPath)) {
      throw new Error("addresses.json not found");
    }
    let addresses: DeploymentAddresses = JSON.parse(
      fs.readFileSync(deployedAddressPath, "utf-8")
    );
    let chain: ChainSlug;

    for (chain of chains) {
      if (!addresses[chain]) continue;

      await hre.changeNetwork(networkToChainSlug[chain]);
      const { socketSigner } = await getSigners();

      const addr: ChainSocketAddresses = addresses[chain]!;
      if (!addr["integrations"]) continue;

      const integrations = addr["integrations"] ?? {};
      const integrationList = Object.keys(integrations);

      const list = isTestnet(chain) ? TestnetIds : MainnetIds;
      const siblingSlugs: ChainSlug[] = list.filter(
        (chainSlug) => chainSlug !== chain
      );

      console.log(`Configuring for ${chain}`);
      let updatedDeploymentAddresses = addr;

      for (let sibling of integrationList) {
        const config = integrations[sibling][IntegrationTypes.native];
        if (!config) continue;
        updatedDeploymentAddresses = await registerSwitchBoard(
          config["switchboard"],
          sibling,
          capacitorType,
          maxPacketLength,
          socketSigner,
          IntegrationTypes.native,
          updatedDeploymentAddresses
        );

        await storeAddresses(updatedDeploymentAddresses, chain);
      }

      // register fast
      for (let sibling of siblingSlugs) {
        updatedDeploymentAddresses = await registerSwitchBoard(
          addr["FastSwitchboard"],
          sibling,
          capacitorType,
          maxPacketLength,
          socketSigner,
          IntegrationTypes.fast,
          updatedDeploymentAddresses
        );

        await storeAddresses(updatedDeploymentAddresses, chain);
      }

      // register optimistic
      for (let sibling of siblingSlugs) {
        let updatedDeploymentAddresses = addr;
        updatedDeploymentAddresses = await registerSwitchBoard(
          addr["OptimisticSwitchboard"],
          sibling,
          capacitorType,
          maxPacketLength,
          socketSigner,
          IntegrationTypes.optimistic,
          updatedDeploymentAddresses
        );

        await storeAddresses(updatedDeploymentAddresses, chain);
      }

      // set gas limit for all siblings
      for (let sibling of siblingSlugs) {
        await setProposeGasLimit(
          chain,
          sibling,
          addr["TransmitManager"],
          proposeGasLimit[networkToChainSlug[sibling]],
          socketSigner
        );

        await setAttestGasLimit(
          chain,
          sibling,
          addr["FastSwitchboard"],
          attestGasLimit[networkToChainSlug[sibling]],
          socketSigner
        );

        await setExecutionOverhead(
          chain,
          sibling,
          addr["FastSwitchboard"],
          executionOverhead[networkToChainSlug[sibling]],
          socketSigner
        );

        await setExecutionOverhead(
          chain,
          sibling,
          addr["OptimisticSwitchboard"],
          executionOverhead[networkToChainSlug[sibling]],
          socketSigner
        );
      }
    }

    await setRemoteSwitchboards(addresses);
  } catch (error) {
    console.log("Error while sending transaction", error);
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
            addresses?.[dstChain]
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

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

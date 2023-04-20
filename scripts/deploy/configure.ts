import fs from "fs";
import hre from "hardhat";
import { constants } from "ethers";
import { networkToChainSlug, switchboards } from "../constants";
import {
  deployedAddressPath,
  getInstance,
  getSigners,
  getSwitchboardAddress,
  storeAddresses,
} from "./utils";
import { ChainSlug, IntegrationTypes, NativeSwitchboard } from "../../src";
import registerSwitchBoard from "./registerSwitchboard";

const capacitorType = 1;
const maxPacketLength = 10;

export const main = async () => {
  try {
    if (!fs.existsSync(deployedAddressPath)) {
      throw new Error("addresses.json not found");
    }
    let addresses = JSON.parse(fs.readFileSync(deployedAddressPath, "utf-8"));
    const chains: ChainSlug[] = Object.keys(addresses) as any as ChainSlug[];
    let chain: ChainSlug;

    for (chain of chains) {
      await hre.changeNetwork(networkToChainSlug[chain]);
      const { socketSigner } = await getSigners();
      const integrations = addresses[chain]["integrations"];

      if (!addresses[chain]["integrations"]) continue;
      const integrationList = Object.keys(integrations);

      console.log(`Configuring for ${chain}`);
      for (let sibling of integrationList) {
        await Promise.all(
          Object.keys(integrations[sibling]).map(async (integration) => {
            const config = integrations[sibling][integration];
            let updatedDeploymentAddresses = addresses[chain];
            updatedDeploymentAddresses = await registerSwitchBoard(
              config["switchboard"],
              sibling,
              capacitorType,
              maxPacketLength,
              socketSigner,
              integration,
              updatedDeploymentAddresses
            );

            await storeAddresses(updatedDeploymentAddresses, chain);
          })
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

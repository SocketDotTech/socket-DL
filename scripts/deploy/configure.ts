import fs from "fs";
import { Wallet, constants } from "ethers";
import { getProviderFromChainName, switchboards } from "../constants";
import {
  deployedAddressPath,
  getInstance,
  getSwitchboardAddress,
  storeAddresses,
} from "./utils";
import {
  CORE_CONTRACTS,
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  IntegrationTypes,
  MainnetIds,
  NativeSwitchboard,
  TestnetIds,
  isTestnet,
  networkToChainSlug,
} from "../../src";
import registerSwitchBoard from "./scripts/registerSwitchboard";
import { capacitorType, chains, maxPacketLength, mode } from "./config";

export const main = async () => {
  try {
    if (!fs.existsSync(deployedAddressPath(mode))) {
      throw new Error("addresses.json not found");
    }
    let addresses: DeploymentAddresses = JSON.parse(
      fs.readFileSync(deployedAddressPath(mode), "utf-8")
    );
    let chain: ChainSlug;

    for (chain of chains) {
      if (!addresses[chain]) continue;

      const providerInstance = getProviderFromChainName(
        networkToChainSlug[chain]
      );
      const socketSigner: Wallet = new Wallet(
        process.env.SOCKET_SIGNER_KEY as string,
        providerInstance
      );
      const addr: ChainSocketAddresses = addresses[chain]!;
      if (!addr["integrations"]) continue;

      const integrations = addr["integrations"] ?? {};
      const integrationList = Object.keys(integrations);

      const list = isTestnet(chain) ? TestnetIds : MainnetIds;
      const siblingSlugs: ChainSlug[] = list.filter(
        (chainSlug) => chainSlug !== chain && chains.includes(chainSlug)
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

        await storeAddresses(updatedDeploymentAddresses, chain, mode);
      }

      // register fast
      for (let sibling of siblingSlugs) {
        updatedDeploymentAddresses = await registerSwitchBoard(
          addr[CORE_CONTRACTS.FastSwitchboard],
          sibling,
          capacitorType,
          maxPacketLength,
          socketSigner,
          IntegrationTypes.fast,
          updatedDeploymentAddresses
        );

        await storeAddresses(updatedDeploymentAddresses, chain, mode);
      }

      // register optimistic
      for (let sibling of siblingSlugs) {
        let updatedDeploymentAddresses = addr;
        updatedDeploymentAddresses = await registerSwitchBoard(
          addr[CORE_CONTRACTS.OptimisticSwitchboard],
          sibling,
          capacitorType,
          maxPacketLength,
          socketSigner,
          IntegrationTypes.optimistic,
          updatedDeploymentAddresses
        );

        await storeAddresses(updatedDeploymentAddresses, chain, mode);
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
      const providerInstance = getProviderFromChainName(
        networkToChainSlug[srcChain]
      );
      const socketSigner: Wallet = new Wallet(
        process.env.SOCKET_SIGNER_KEY as string,
        providerInstance
      );

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
            sbContract = (
              await getInstance("PolygonL1Switchboard", srcSwitchboardAddress)
            ).connect(socketSigner);

            const fxChild = await sbContract.fxChildTunnel();
            if (fxChild !== constants.AddressZero) continue;

            functionName = "setFxChildTunnel";
            console.log(
              `Setting ${dstSwitchboardAddress} fx child tunnel in ${srcSwitchboardAddress} on networks ${srcChain}-${dstChain}`
            );
          } else if (srcSwitchboardType === NativeSwitchboard.POLYGON_L2) {
            sbContract = (
              await getInstance("PolygonL2Switchboard", srcSwitchboardAddress)
            ).connect(socketSigner);

            const fxRoot = await sbContract.fxRootTunnel();
            if (fxRoot !== constants.AddressZero) continue;

            functionName = "setFxRootTunnel";
            console.log(
              `Setting ${dstSwitchboardAddress} fx root tunnel in ${srcSwitchboardAddress} on networks ${srcChain}-${dstChain}`
            );
          } else {
            sbContract = (
              await getInstance("ArbitrumL1Switchboard", srcSwitchboardAddress)
            ).connect(socketSigner);

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

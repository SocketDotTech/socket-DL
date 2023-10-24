import fs from "fs";
import { Wallet } from "ethers";

import { getProviderFromChainSlug } from "../constants";
import {
  deployedAddressPath,
  getSwitchboardAddress,
  storeAllAddresses,
} from "./utils";
import {
  CORE_CONTRACTS,
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  IntegrationTypes,
  MainnetIds,
  TestnetIds,
  isTestnet,
} from "../../src";
import registerSwitchboardForSibling from "./scripts/registerSwitchboard";
import {
  capacitorType,
  chains,
  maxPacketLength,
  mode,
  executionManagerVersion,
} from "./config";
import { configureExecutionManager, registerSwitchboards, setManagers, setupPolygonNativeSwitchboard } from "./scripts/configureSocket";

export const main = async () => {
  try {
    if (!fs.existsSync(deployedAddressPath(mode))) {
      throw new Error("addresses.json not found");
    }
    let addresses: DeploymentAddresses = JSON.parse(
      fs.readFileSync(deployedAddressPath(mode), "utf-8")
    );

    await Promise.all(
      chains.map(async (chain) => {
        if (!addresses[chain]) return;

        const providerInstance = getProviderFromChainSlug(
          chain as any as ChainSlug
        );
        const socketSigner: Wallet = new Wallet(
          process.env.SOCKET_SIGNER_KEY as string,
          providerInstance
        );

        let addr: ChainSocketAddresses = addresses[chain]!;

        const list = isTestnet(chain) ? TestnetIds : MainnetIds;
        const siblingSlugs: ChainSlug[] = list.filter(
          (chainSlug) => chainSlug !== chain && chains.includes(chainSlug)
        );

        await configureExecutionManager(
          executionManagerVersion,
          addr[executionManagerVersion]!,
          addr[CORE_CONTRACTS.SocketBatcher],
          chain,
          siblingSlugs,
          socketSigner
        );

        await setManagers(addr, socketSigner);

        const integrations = addr["integrations"] ?? {};
        const integrationList = Object.keys(integrations).filter((chain) =>
          chains.includes(parseInt(chain) as ChainSlug)
        );

        console.log(`Configuring for ${chain}`);

        for (let sibling of integrationList) {
          const config = integrations[sibling][IntegrationTypes.native];
          if (!config) continue;

          const siblingSwitchboard = getSwitchboardAddress(
            chain,
            IntegrationTypes.native,
            addresses?.[sibling]
          );

          if (!siblingSwitchboard) continue;

          addr = await registerSwitchboardForSibling(
            config["switchboard"],
            siblingSwitchboard,
            sibling,
            capacitorType,
            maxPacketLength,
            socketSigner,
            IntegrationTypes.native,
            addr
          );
        }

        addr = await registerSwitchboards(
          chain,
          siblingSlugs,
          CORE_CONTRACTS.FastSwitchboard2,
          IntegrationTypes.fast2,
          addr,
          addresses,
          socketSigner
        );

        addr = await registerSwitchboards(
          chain,
          siblingSlugs,
          CORE_CONTRACTS.OptimisticSwitchboard,
          IntegrationTypes.optimistic,
          addr,
          addresses,
          socketSigner
        );

        addresses[chain] = addr;

        console.log(`Configuring for ${chain} - COMPLETED`);
      })
    );

    await storeAllAddresses(addresses, mode);
    await setupPolygonNativeSwitchboard(addresses);
  } catch (error) {
    console.log("Error while sending transaction", error);
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

import { Wallet } from "ethers";

import { getProviderFromChainSlug } from "../../constants";
import { storeAllAddresses } from "../utils";
import {
  CORE_CONTRACTS,
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  IntegrationTypes,
  MainnetIds,
  TestnetIds,
  getSwitchboardAddressFromAllAddresses,
  isTestnet,
} from "../../../src";
import registerSwitchboardForSibling from "./registerSwitchboard";
import {
  capacitorType,
  maxPacketLength,
  mode,
  executionManagerVersion,
} from "../config/config";
import {
  configureExecutionManager,
  registerSwitchboards,
  setManagers,
  setupPolygonNativeSwitchboard,
} from "./configureSocket";

export const configureSwitchboards = async (
  addresses: DeploymentAddresses,
  chains: ChainSlug[]
) => {
  try {
    await Promise.all(
      filterChains.map(async (chain) => {
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
          (chainSlug) =>
            chainSlug !== chain && filterSiblingChains.includes(chainSlug)
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
          filterSiblingChains.includes(parseInt(chain) as ChainSlug)
        );

        console.log(`Configuring for ${chain}`);

        for (let sibling of integrationList) {
          const nativeConfig = integrations[sibling][IntegrationTypes.native];
          if (!nativeConfig) continue;

          const siblingSwitchboard = getSwitchboardAddressFromAllAddresses(
            addresses,
            chain,
            parseInt(sibling) as ChainSlug,
            IntegrationTypes.native
          );

          if (!siblingNativeSwitchboard) continue;
          addr = await registerSwitchboardForSibling(
            nativeConfig["switchboard"],
            siblingNativeSwitchboard,
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
          CORE_CONTRACTS.FastSwitchboard,
          IntegrationTypes.fast,
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

  return addresses;
};

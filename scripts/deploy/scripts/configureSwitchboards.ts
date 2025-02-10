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
import { capacitorType, maxPacketLength, mode } from "../config/config";
import {
  configureExecutionManager,
  registerSwitchboards,
  setManagers,
  setupPolygonNativeSwitchboard,
} from "./configureSocket";
import { SocketSigner } from "@socket.tech/dl-common";
import { getSocketSigner } from "../utils/socket-signer";

export const configureSwitchboards = async (
  addresses: DeploymentAddresses,
  chains: ChainSlug[],
  siblings: ChainSlug[],
  safeChains: ChainSlug[],
  executionManagerVersion: CORE_CONTRACTS
) => {
  try {
    console.log("=========== configuring switchboards ===========");
    await Promise.all(
      chains.map(async (chain) => {
        if (!addresses[chain]) return;
        let addr: ChainSocketAddresses = addresses[chain]!;
        const socketSigner: SocketSigner = await getSocketSigner(
          chain,
          addr,
          safeChains.includes(chain),
          !safeChains.includes(chain)
        );

        await configureExecutionManager(
          executionManagerVersion,
          addr[executionManagerVersion]!,
          addr[CORE_CONTRACTS.SocketBatcher],
          chain,
          siblings,
          socketSigner
        );

        await setManagers(addr, socketSigner, executionManagerVersion);

        const integrations = addr["integrations"] ?? {};
        const integrationList = Object.keys(integrations).filter((chain) =>
          siblings.includes(parseInt(chain) as ChainSlug)
        );

        console.log(`Configuring switchboards for ${chain}`);

        for (let sibling of integrationList) {
          const nativeConfig = integrations[sibling][IntegrationTypes.native];
          if (!nativeConfig) continue;

          const siblingSwitchboard = getSwitchboardAddressFromAllAddresses(
            addresses,
            chain,
            parseInt(sibling) as ChainSlug,
            IntegrationTypes.native
          );

          if (!siblingSwitchboard) continue;
          addr = await registerSwitchboardForSibling(
            nativeConfig["switchboard"],
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
          siblings,
          CORE_CONTRACTS.FastSwitchboard,
          IntegrationTypes.fast,
          addr,
          addresses,
          socketSigner
        );

        addr = await registerSwitchboards(
          chain,
          siblings,
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
    await setupPolygonNativeSwitchboard(addresses, safeChains);
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }

  return addresses;
};

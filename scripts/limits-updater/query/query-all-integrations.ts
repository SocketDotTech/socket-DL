import {
  ChainAddresses,
  ChainSocketAddresses,
  Configs,
  Integrations,
} from "../../../src";
import {
  getAddresses,
  getChainSlugsFromDeployedAddresses,
} from "../../deploy/utils";

// npx ts-node scripts/limits-updater/query-all-integrations.ts
export const main = async () => {
  const chainSlugsDecoded: string[] =
    (await getChainSlugsFromDeployedAddresses()) as string[];

  console.log(`-------------------------------------\n\n`);

  for (let slugIndex = 0; slugIndex < chainSlugsDecoded.length; slugIndex++) {
    const chainSlug = parseInt(chainSlugsDecoded[slugIndex]);

    const addresses = (await getAddresses(chainSlug)) as ChainSocketAddresses;

    const integrations: Integrations = addresses.integrations as Integrations;

    const transmitManager: string = addresses.TransmitManager as string;

    if (integrations) {
      console.log(`For sourceChainId: ${chainSlug} \n`);

      const keys = Object.keys(integrations);
      const values = Object.values(integrations);

      for (let i = 0; i < keys.length; i++) {
        const key = keys[i].toString();
        const chainAddresses: ChainAddresses = values[i];

        console.log(`for remoteChainId: ${key}`);

        if (chainAddresses.FAST) {
          const config: Configs = chainAddresses.FAST as Configs;
          console.log(`FAST Switchboard address is: ${config.switchboard}`);
        }

        if (chainAddresses.OPTIMISTIC) {
          const config: Configs = chainAddresses.OPTIMISTIC as Configs;
          console.log(
            `Optimistic Switchboard address is: ${config.switchboard}`
          );
        }

        if (chainAddresses.NATIVE_BRIDGE) {
          const config: Configs = chainAddresses.NATIVE_BRIDGE as Configs;
          console.log(`Native Switchboard address is: ${config.switchboard}`);
        }
      }

      console.log(`-------------------------------------\n\n`);
    }
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

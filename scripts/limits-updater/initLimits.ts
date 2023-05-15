import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { attestGasLimit, executionOverhead } from "../constants";
import {
  ChainAddresses,
  ChainSocketAddresses,
  Configs,
  Integrations,
  chainKeyToSlug,
} from "../../src/types";
import { getAddresses } from "../deploy/utils";
import { setAttestGasLimit } from "./set-attest-gaslimit";
import { setExecutionOverhead } from "./set-execution-overhead";
import { mode } from "../deploy/config";

export const setLimitsForAChainSlug = async (
  chainSlugCode: keyof typeof chainKeyToSlug
) => {
  try {
    const chainId = chainKeyToSlug[chainSlugCode];
    console.log(
      `setting initLimits for chainSlug: ${chainSlugCode} and chainId: ${chainId}`
    );

    const deployedAddressConfig = (await getAddresses(
      chainId,
      mode
    )) as ChainSocketAddresses;

    console.log(
      `deployedAddressConfig are: ${JSON.stringify(deployedAddressConfig)}`
    );

    const integrations: Integrations =
      deployedAddressConfig.integrations as Integrations;

    console.log(`integrations are: ${JSON.stringify(integrations)}`);

    //get TransmitManager Address
    const transmitManagerAddress =
      deployedAddressConfig.TransmitManager as string;

    if (integrations) {
      console.log(`For sourceChainId: ${chainId} \n`);

      const keys = Object.keys(integrations);
      const values = Object.values(integrations);

      for (let i = 0; i < keys.length; i++) {
        const key = keys[i].toString();
        const dstChainId = parseInt(key);
        const chainAddresses: ChainAddresses = values[i];

        const chainSlugCode = "optimism-goerli";
        // networkToChainSlug[dstChainId]

        if (chainAddresses.FAST) {
          const config: Configs = chainAddresses.FAST as Configs;
          const switchboardAddress = config.switchboard as string;
          console.log(`FAST Switchboard address is: ${config.switchboard}`);

          //lookup for AttestGasLimit for the chainSlugCode
          const attestGasLimitValue = attestGasLimit[chainSlugCode];

          const isAttestUpdateSuccessful = await setAttestGasLimit(
            chainId,
            dstChainId,
            switchboardAddress,
            attestGasLimitValue
          );

          console.log(
            `FAST-Switchboard Successfully updated attestGasLimit: ${attestGasLimitValue} for chainId: ${chainId} and dstChainId: ${dstChainId}`
          );

          //lookup for executionOverhead for the chainSlugCode
          const executionOverheadValue = executionOverhead[chainSlugCode];

          await setExecutionOverhead(
            chainId,
            dstChainId,
            switchboardAddress,
            executionOverheadValue
          );

          console.log(
            `FAST-Switchboard Successfully updated executionOverhead: ${executionOverheadValue} for chainId: ${chainId} and dstChainId: ${dstChainId}`
          );
        }

        if (chainAddresses.OPTIMISTIC) {
          const config: Configs = chainAddresses.OPTIMISTIC as Configs;
          const switchboardAddress = config.switchboard as string;
          console.log(
            `Optimistic Switchboard address is: ${config.switchboard}`
          );

          //lookup for executionOverhead for the chainSlugCode
          const executionOverheadValue = executionOverhead[chainSlugCode];

          await setExecutionOverhead(
            chainId,
            dstChainId,
            switchboardAddress,
            executionOverheadValue
          );

          console.log(
            `OPTIMISTIC-Switchboard Successfully updated executionOverhead: ${executionOverheadValue} for chainId: ${chainId} and dstChainId: ${dstChainId}`
          );
        }
      }

      console.log(`-------------------------------------\n\n`);
    }
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

// npx ts-node scripts/limits-updater/initLimits.ts
export const setLimits = async () => {
  try {
    // for (let chainSlugKey of chainSlugKeys) {
    //   setLimitsForAChainSlug(chainSlugKey as keyof typeof chainKeyToSlug);
    // }
    setLimitsForAChainSlug("optimism-goerli");
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

setLimits()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

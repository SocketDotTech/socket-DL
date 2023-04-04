import {
  attestGasLimit,
  chainSlugKeys,
  chainSlugs,
  executionOverhead,
  networkToChainSlug,
  proposeGasLimit,
} from "../constants";
import {
  ChainAddresses,
  ChainSocketAddresses,
  Configs,
  Integrations,
} from "../../src/types";
import { getAddresses } from "../deploy/utils";
import { setAttestGasLimit } from "./set-attest-gaslimit";
import { setExecutionOverhead } from "./set-execution-overhead";
import { setProposeGasLimit } from "./set-propose-gaslimit";

export const setLimitsForAChainSlug = async (
  chainSlugCode: keyof typeof chainSlugs
) => {
  try {
    const chainId = chainSlugs[chainSlugCode];
    console.log(
      `setting initLimits for chainSlug: ${chainSlugCode} and chainId: ${chainId}`
    );

    const deployedAddressConfig = (await getAddresses(
      chainId
    )) as ChainSocketAddresses;

    const integrations: Integrations =
      deployedAddressConfig.integrations as Integrations;

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

        //lookup for proposeGasLimit for the chainSlugCode
        const proposeGasLimitValue =
          proposeGasLimit[networkToChainSlug[dstChainId]];

        const isProposeUpdateSuccessful = await setProposeGasLimit(
          chainId,
          dstChainId,
          transmitManagerAddress,
          proposeGasLimitValue
        );

        if(isProposeUpdateSuccessful) {
          console.log(`TransmitManager - Successfully updated proposeLimit: ${proposeGasLimitValue} for chainId: ${chainId} and dstChainId: ${dstChainId}`);
        } else {
          throw new Error(`TransmitManager - Failed to update proposeLimit: ${proposeGasLimitValue} for chainId: ${chainId} and dstChainId: ${dstChainId}`);
        }

        if (chainAddresses.FAST) {
          const config: Configs = chainAddresses.FAST as Configs;
          const switchboardAddress = config.switchboard as string;
          console.log(`FAST Switchboard address is: ${config.switchboard}`);

          //lookup for AttestGasLimit for the chainSlugCode
          const attestGasLimitValue =
            attestGasLimit[networkToChainSlug[dstChainId]];

            const isAttestUpdateSuccessful = await setAttestGasLimit(
            chainId,
            dstChainId,
            switchboardAddress,
            attestGasLimitValue
          );

          console.log(`FAST-Switchboard Successfully updated attestGasLimit: ${attestGasLimitValue} for chainId: ${chainId} and dstChainId: ${dstChainId}`)

          //lookup for executionOverhead for the chainSlugCode
          const executionOverheadValue =
            executionOverhead[networkToChainSlug[dstChainId]];

          await setExecutionOverhead(
            chainId,
            dstChainId,
            switchboardAddress,
            executionOverheadValue
          );

          console.log(`FAST-Switchboard Successfully updated executionOverhead: ${executionOverheadValue} for chainId: ${chainId} and dstChainId: ${dstChainId}`)
        }

        if (chainAddresses.OPTIMISTIC) {
          const config: Configs = chainAddresses.OPTIMISTIC as Configs;
          const switchboardAddress = config.switchboard as string;
          console.log(
            `Optimistic Switchboard address is: ${config.switchboard}`
          );

          //lookup for executionOverhead for the chainSlugCode
          const executionOverheadValue =
            executionOverhead[networkToChainSlug[dstChainId]];

          await setExecutionOverhead(
            chainId,
            dstChainId,
            switchboardAddress,
            executionOverheadValue
          );

          console.log(`OPTIMISTIC-Switchboard Successfully updated executionOverhead: ${executionOverheadValue} for chainId: ${chainId} and dstChainId: ${dstChainId}`)
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
    for (let chainSlugKey of chainSlugKeys) {
      setLimitsForAChainSlug(chainSlugKey as keyof typeof chainSlugs);
    }
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

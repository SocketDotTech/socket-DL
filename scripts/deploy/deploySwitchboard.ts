import { createObj, deployContractWithArgs, storeAddresses } from "./utils";
import { chainSlugs, switchboards } from "../constants";
import { ChainSocketAddresses, IntegrationTypes } from "../../src";
import { getSwitchboardDeployData } from "./switchboards";
import { Wallet } from "ethers";

export default async function deploySwitchboards(
  network: string,
  signer: Wallet,
  sourceConfig: ChainSocketAddresses,
  verificationDetails: any[]
): Promise<Object> {
  let result: any = { sourceConfig, verificationDetails };

  if (!sourceConfig.FastSwitchboard)
    result = await deploySwitchboard(
      IntegrationTypes.fast,
      network,
      "",
      signer,
      sourceConfig,
      verificationDetails
    );

  if (!sourceConfig.OptimisticSwitchboard)
    result = await deploySwitchboard(
      IntegrationTypes.optimistic,
      network,
      "",
      signer,
      result.sourceConfig,
      result.verificationDetails
    );

  if (!switchboards[network]) return sourceConfig;
  const siblings = Object.keys(switchboards[network]);
  for (let index = 0; index < siblings.length; index++) {
    if (
      !sourceConfig?.integrations?.[chainSlugs[siblings[index]]]?.[
        IntegrationTypes.native
      ]?.["switchboard"]
    )
      result = await deploySwitchboard(
        IntegrationTypes.native,
        network,
        siblings[index],
        signer,
        result.sourceConfig,
        result.verificationDetails
      );
  }

  return {
    sourceConfig: result.sourceConfig,
    verificationDetails: result.verificationDetails,
  };
}

async function deploySwitchboard(
  integrationType: IntegrationTypes,
  network: string,
  remoteChain: string,
  signer: Wallet,
  sourceConfig: ChainSocketAddresses,
  verificationDetails: any[]
): Promise<Object> {
  try {
    const { contractName, args, path } = getSwitchboardDeployData(
      integrationType,
      network,
      remoteChain,
      sourceConfig["Socket"],
      sourceConfig["GasPriceOracle"],
      signer.address
    );

    const switchboard = await deployContractWithArgs(
      contractName,
      args,
      signer
    );
    verificationDetails.push([switchboard.address, contractName, path, args]);

    sourceConfig = createObj(
      sourceConfig,
      ["integrations", chainSlugs[remoteChain], integrationType, "switchboard"],
      switchboard.address
    );

    if (integrationType === IntegrationTypes.optimistic) {
      sourceConfig["OptimisticSwitchboard"] = switchboard.address;
    }
    if (integrationType === IntegrationTypes.fast) {
      sourceConfig["FastSwitchboard"] = switchboard.address;
    }

    await storeAddresses(sourceConfig, chainSlugs[network]);
  } catch (error) {
    console.log("Error in deploying switchboard", error);
    throw error;
  }
  return { sourceConfig, verificationDetails };
}

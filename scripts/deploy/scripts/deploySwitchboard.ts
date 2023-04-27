import { createObj, deployContractWithArgs } from "../utils";
import { switchboards } from "../../constants";
import {
  ChainSocketAddresses,
  DeploymentMode,
  IntegrationTypes,
  chainKeyToSlug,
} from "../../../src";
import { getSwitchboardDeployData } from "../switchboards";
import { Wallet } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

export default async function deploySwitchboards(
  network: string,
  signer: SignerWithAddress | Wallet,
  sourceConfig: ChainSocketAddresses,
  verificationDetails: any[],
  mode: DeploymentMode
): Promise<Object> {
  let result: any = { sourceConfig, verificationDetails };

  if (!sourceConfig.FastSwitchboard)
    result = await deploySwitchboard(
      IntegrationTypes.fast,
      network,
      "",
      signer,
      sourceConfig,
      verificationDetails,
      mode
    );

  if (!sourceConfig.OptimisticSwitchboard)
    result = await deploySwitchboard(
      IntegrationTypes.optimistic,
      network,
      "",
      signer,
      result.sourceConfig,
      result.verificationDetails,
      mode
    );

  if (!switchboards[network]) return result;
  const siblings = Object.keys(switchboards[network]);
  for (let index = 0; index < siblings.length; index++) {
    if (
      !sourceConfig?.integrations?.[chainKeyToSlug[siblings[index]]]?.[
        IntegrationTypes.native
      ]?.["switchboard"]
    )
      result = await deploySwitchboard(
        IntegrationTypes.native,
        network,
        siblings[index],
        signer,
        result.sourceConfig,
        result.verificationDetails,
        mode
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
  signer: SignerWithAddress | Wallet,
  sourceConfig: ChainSocketAddresses,
  verificationDetails: any[],
  mode: DeploymentMode
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
      [
        "integrations",
        chainKeyToSlug[remoteChain],
        integrationType,
        "switchboard",
      ],
      switchboard.address
    );

    if (integrationType === IntegrationTypes.optimistic) {
      sourceConfig["OptimisticSwitchboard"] = switchboard.address;
    }
    if (integrationType === IntegrationTypes.fast) {
      sourceConfig["FastSwitchboard"] = switchboard.address;
    }
  } catch (error) {
    console.log("Error in deploying switchboard", error);
    throw error;
  }
  return { sourceConfig, verificationDetails };
}

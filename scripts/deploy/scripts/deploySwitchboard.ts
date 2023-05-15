import {
  createObj,
  deployContractWithArgs,
  storeVerificationParams,
} from "../utils";
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
  mode: DeploymentMode
): Promise<ChainSocketAddresses> {
  let result: any = { sourceConfig };

  if (!sourceConfig.FastSwitchboard)
    result = await deploySwitchboard(
      IntegrationTypes.fast,
      network,
      "",
      signer,
      sourceConfig,
      mode
    );

  if (!sourceConfig.OptimisticSwitchboard)
    result = await deploySwitchboard(
      IntegrationTypes.optimistic,
      network,
      "",
      signer,
      result.sourceConfig,
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
        mode
      );
  }

  return result.sourceConfig;
}

async function deploySwitchboard(
  integrationType: IntegrationTypes,
  network: string,
  remoteChain: string,
  signer: SignerWithAddress | Wallet,
  sourceConfig: ChainSocketAddresses,
  mode: DeploymentMode
): Promise<ChainSocketAddresses> {
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
    await storeVerificationParams(
      [switchboard.address, contractName, path, args],
      chainKeyToSlug[network],
      mode
    );

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
  return sourceConfig;
}

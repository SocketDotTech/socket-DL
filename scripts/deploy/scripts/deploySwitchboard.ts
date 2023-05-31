import {
  createObj,
  deployContractWithArgs,
  storeVerificationParams,
} from "../utils";
import { switchboards } from "../../constants";
import {
  CORE_CONTRACTS,
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
  let updatedConfig: any = sourceConfig;
  if (!sourceConfig.FastSwitchboard)
    updatedConfig = await deploySwitchboard(
      IntegrationTypes.fast,
      network,
      "",
      signer,
      updatedConfig,
      mode
    );

  if (!sourceConfig.OptimisticSwitchboard)
    updatedConfig = await deploySwitchboard(
      IntegrationTypes.optimistic,
      network,
      "",
      signer,
      updatedConfig,
      mode
    );

  if (!switchboards[network]) return updatedConfig;
  const siblings = Object.keys(switchboards[network]);
  for (let index = 0; index < siblings.length; index++) {
    if (
      !updatedConfig?.integrations?.[chainKeyToSlug[siblings[index]]]?.[
        IntegrationTypes.native
      ]?.["switchboard"]
    ) {
      updatedConfig = await deploySwitchboard(
        IntegrationTypes.native,
        network,
        siblings[index],
        signer,
        updatedConfig,
        mode
      );
    }
  }

  return updatedConfig;
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
      sourceConfig[CORE_CONTRACTS.Socket],
      sourceConfig[CORE_CONTRACTS.SignatureVerifier],
      signer.address
    );

    const switchboard = await deployContractWithArgs(
      contractName,
      args,
      signer
    );

    console.log(
      `${contractName} Switchboard deployed at ${switchboard.address}`
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
      sourceConfig[CORE_CONTRACTS.OptimisticSwitchboard] = switchboard.address;
    }
    if (integrationType === IntegrationTypes.fast) {
      sourceConfig[CORE_CONTRACTS.FastSwitchboard] = switchboard.address;
    }
  } catch (error) {
    console.log("Error in deploying switchboard", error);
    throw error;
  }
  return sourceConfig;
}

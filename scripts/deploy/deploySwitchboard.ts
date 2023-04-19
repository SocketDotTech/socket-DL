import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { createObj, deployContractWithArgs, storeAddresses } from "./utils";
import { chainSlugs, switchboards } from "../constants";
import { ChainSocketAddresses, IntegrationTypes } from "../../src";
import { getSwitchboardDeployData } from "./switchboards";

export default async function deploySwitchboards(
  network: string,
  signer: SignerWithAddress,
  sourceConfig: ChainSocketAddresses
): Promise<ChainSocketAddresses> {
  sourceConfig = await deploySwitchboard(
    IntegrationTypes.fast,
    network,
    "",
    signer,
    sourceConfig
  );

  sourceConfig = await deploySwitchboard(
    IntegrationTypes.optimistic,
    network,
    "",
    signer,
    sourceConfig
  );

  if (!switchboards[network]) return sourceConfig;
  const siblings = Object.keys(switchboards[network]);
  for (let index = 0; index < siblings.length; index++) {
    sourceConfig = await deploySwitchboard(
      IntegrationTypes.native,
      network,
      siblings[index],
      signer,
      sourceConfig
    );
  }

  return sourceConfig;
}

async function deploySwitchboard(
  integrationType: IntegrationTypes,
  network: string,
  remoteChain: string,
  signer: SignerWithAddress,
  sourceConfig: ChainSocketAddresses
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

    console.log(contractName, args, path);

    const switchboard = await deployContractWithArgs(
      contractName,
      args,
      signer,
      path
    );

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
    return sourceConfig;
  } catch (error) {
    console.log("Error in deploying switchboard", error);
    throw error;
  }
}

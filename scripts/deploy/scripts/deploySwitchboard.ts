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
  ChainSlug,
} from "../../../src";
import { getSwitchboardDeployData } from "../switchboards";
import { SocketSigner } from "@socket.tech/dl-common";

export default async function deploySwitchboards(
  chainSlug: ChainSlug,
  owner: string,
  signer: SocketSigner,
  sourceConfig: ChainSocketAddresses,
  mode: DeploymentMode
): Promise<ChainSocketAddresses> {
  let updatedConfig: any = sourceConfig;
  if (!sourceConfig.FastSwitchboard)
    updatedConfig = await deploySwitchboard(
      IntegrationTypes.fast,
      chainSlug,
      "",
      owner,
      signer,
      updatedConfig,
      mode
    );

  if (!sourceConfig.OptimisticSwitchboard)
    updatedConfig = await deploySwitchboard(
      IntegrationTypes.optimistic,
      chainSlug,
      "",
      owner,
      signer,
      updatedConfig,
      mode
    );

  if (!switchboards[chainSlug]) return updatedConfig;
  const siblings: ChainSlug[] = Object.keys(switchboards[chainSlug]).map(
    (c) => parseInt(c) as ChainSlug
  );

  for (let index = 0; index < siblings.length; index++) {
    if (
      !updatedConfig?.integrations?.[siblings[index]]?.[
        IntegrationTypes.native
      ]?.["switchboard"]
    ) {
      updatedConfig = await deploySwitchboard(
        IntegrationTypes.native,
        chainSlug,
        siblings[index],
        owner,
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
  chainSlug: ChainSlug,
  remoteChain: ChainSlug | string,
  owner: string,
  signer: SocketSigner,
  sourceConfig: ChainSocketAddresses,
  mode: DeploymentMode
): Promise<ChainSocketAddresses> {
  try {
    const { contractName, args, path } = getSwitchboardDeployData(
      integrationType,
      chainSlug,
      remoteChain,
      sourceConfig[CORE_CONTRACTS.Socket],
      sourceConfig[CORE_CONTRACTS.SignatureVerifier],
      owner
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
      chainSlug,
      mode
    );

    if (remoteChain.toString().length > 0)
      sourceConfig = createObj(
        sourceConfig,
        [
          "integrations",
          remoteChain.toString(),
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
    if (integrationType === IntegrationTypes.fast2) {
      sourceConfig[CORE_CONTRACTS.FastSwitchboard2] = switchboard.address;
    }
  } catch (error) {
    console.log("Error in deploying switchboard", error);
    throw error;
  }
  return sourceConfig;
}

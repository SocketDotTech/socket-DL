import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { createObj, deployContractWithArgs, getInstance, getSwitchboardAddress } from "./utils";
import { chainIds } from "../constants";
import registerSwitchBoard from "./scripts/registerSwitchboard";
import { IntegrationTypes } from "../../src";
import { getSwitchboardDeployData } from "./switchboards";
import { setupFast } from "./switchboards/fastSwitchboard";
import { setupOptimistic } from "./switchboards/optimisticSwitchboard";


export default async function deployAndRegisterSwitchboard(
  integrationType: IntegrationTypes,
  network: string,
  capacitorType: number,
  remoteChain: string,
  signer: SignerWithAddress,
  sourceConfig: object
) {
  try {
    const remoteChainSlug = chainIds[remoteChain];

    const switchboardAddress = getSwitchboardAddress(chainIds[remoteChain], IntegrationTypes.nativeIntegration, sourceConfig)
    const socket = await getInstance("Socket", sourceConfig["Socket"]);

    const { contractName, args } = getSwitchboardDeployData(integrationType, network, remoteChain, sourceConfig["Socket"], sourceConfig["GasPriceOracle"], signer.address);

    let switchboard: Contract;
    if (!switchboardAddress) {
      switchboard = await deployContractWithArgs(contractName, args, signer);
      sourceConfig = createObj(
        sourceConfig,
        ["integrations", chainIds[remoteChain], IntegrationTypes.nativeIntegration, "switchboard"],
        switchboard.address
      );

      if (contractName === "FastSwitchboard") {
        await setupFast(switchboard, chainIds[remoteChain], remoteChain, signer);
      } else if (contractName === "FastSwitchboard") {
        await setupOptimistic(switchboard, chainIds[remoteChain], remoteChain, signer)
      }
    } else {
      switchboard = await getInstance(contractName, switchboardAddress)
    }

    sourceConfig = await registerSwitchBoard(socket, switchboard.address, remoteChainSlug, capacitorType, signer, IntegrationTypes.nativeIntegration, sourceConfig);
    return sourceConfig;
  } catch (error) {
    console.log("Error in deploying switchboard", error);
    throw error;
  }
};

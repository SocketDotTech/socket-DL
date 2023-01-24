import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { createObj, deployContractWithArgs, getInstance, getSwitchboardAddress, storeAddresses } from "./utils";
import { chainIds } from "../constants";
import registerSwitchBoard from "./scripts/registerSwitchboard";
import { ChainSocketAddresses, IntegrationTypes } from "../../src";
import { getSwitchboardDeployData } from "./switchboards";
import { setupFast } from "./switchboards/fastSwitchboard";
import { setupOptimistic } from "./switchboards/optimisticSwitchboard";


export default async function deployAndRegisterSwitchboard(
  integrationType: IntegrationTypes,
  network: string,
  capacitorType: number,
  remoteChain: string,
  signer: SignerWithAddress,
  sourceConfig: ChainSocketAddresses
) {
  try {
    const remoteChainSlug = chainIds[remoteChain];

    const switchboardAddress = getSwitchboardAddress(chainIds[remoteChain], integrationType, sourceConfig)
    const { contractName, args, path } = getSwitchboardDeployData(integrationType, network, remoteChain, sourceConfig["Socket"], sourceConfig["GasPriceOracle"], signer.address);

    let switchboard: Contract;
    if (!switchboardAddress) {
      switchboard = await deployContractWithArgs(contractName, args, signer, path);
      sourceConfig = createObj(
        sourceConfig,
        ["integrations", chainIds[remoteChain], integrationType, "switchboard"],
        switchboard.address
      );
      await storeAddresses(sourceConfig, chainIds[network]);
    } else {
      switchboard = await getInstance(contractName, switchboardAddress)
    }

    if (contractName === "FastSwitchboard") {
      await setupFast(switchboard, chainIds[remoteChain], network, remoteChain, signer);
    } else if (contractName === "OptimisticSwitchboard") {
      await setupOptimistic(switchboard, chainIds[remoteChain], network, remoteChain, signer)
    }

    sourceConfig = await registerSwitchBoard(switchboard.address, remoteChainSlug, capacitorType, signer, integrationType, sourceConfig);
    await storeAddresses(sourceConfig, chainIds[network]);

    return sourceConfig;
  } catch (error) {
    console.log("Error in deploying switchboard", error);
    throw error;
  }
};

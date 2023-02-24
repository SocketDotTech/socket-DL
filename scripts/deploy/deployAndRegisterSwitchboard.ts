import { constants, Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  createObj,
  deployContractWithArgs,
  getCapacitorAddress,
  getInstance,
  getSwitchboardAddress,
  storeAddresses,
} from "./utils";
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

    const result = getOrStoreSwitchboardAddress(
      chainIds[remoteChain],
      integrationType,
      sourceConfig
    );
    const { contractName, args, path } = getSwitchboardDeployData(
      integrationType,
      network,
      remoteChain,
      sourceConfig["GasPriceOracle"],
      signer.address
    );

    let switchboard: Contract;
    sourceConfig = result.sourceConfig;
    if (!result.switchboardAddr) {
      switchboard = await deployContractWithArgs(
        contractName,
        args,
        signer,
        path
      );
      sourceConfig = createObj(
        sourceConfig,
        ["integrations", chainIds[remoteChain], integrationType, "switchboard"],
        switchboard.address
      );

      if (integrationType === IntegrationTypes.optimistic) {
        sourceConfig["OptimisticSwitchboard"] = switchboard.address;
      }
      if (integrationType === IntegrationTypes.fast) {
        sourceConfig["FastSwitchboard"] = switchboard.address;
      }

      await storeAddresses(sourceConfig, chainIds[network]);
    } else {
      switchboard = await getInstance(contractName, result.switchboardAddr);
    }

    sourceConfig = await registerSwitchBoard(
      switchboard.address,
      remoteChainSlug,
      capacitorType,
      signer,
      integrationType,
      sourceConfig
    );
    await storeAddresses(sourceConfig, chainIds[network]);

    if (contractName === "FastSwitchboard") {
      await setupFast(
        switchboard,
        chainIds[remoteChain],
        network,
        remoteChain,
        signer
      );
    } else if (contractName === "OptimisticSwitchboard") {
      await setupOptimistic(
        switchboard,
        chainIds[remoteChain],
        network,
        remoteChain,
        signer
      );
    } else {
      const capacitor = getCapacitorAddress(
        remoteChainSlug,
        IntegrationTypes.native,
        sourceConfig
      );
      const capacitorAddr = await switchboard.capacitor__();
      if (
        capacitorAddr.toString().toLowerCase() !==
        capacitor.toString().toLowerCase()
      ) {
        const setCapacitorTx = await switchboard
          .connect(signer)
          .setCapacitor(capacitor);
        console.log(`Adding Capacitor ${capacitor}: ${setCapacitorTx.hash}`);
        await setCapacitorTx.wait();
      }
    }

    return sourceConfig;
  } catch (error) {
    console.log("Error in deploying switchboard", error);
    throw error;
  }
}

const getOrStoreSwitchboardAddress = (
  remoteChain,
  integrationType,
  sourceConfig
) => {
  let switchboardAddr = getSwitchboardAddress(
    remoteChain,
    integrationType,
    sourceConfig
  );

  if (switchboardAddr) {
    if (integrationType === IntegrationTypes.optimistic) {
      sourceConfig = createObj(
        sourceConfig,
        ["integrations", remoteChain, integrationType, "switchboard"],
        switchboardAddr
      );
      switchboardAddr = sourceConfig["OptimisticSwitchboard"];
    } else if (integrationType === IntegrationTypes.fast) {
      sourceConfig = createObj(
        sourceConfig,
        ["integrations", remoteChain, integrationType, "switchboard"],
        switchboardAddr
      );
      switchboardAddr = sourceConfig["FastSwitchboard"];
    }
  }

  return { switchboardAddr, sourceConfig };
};

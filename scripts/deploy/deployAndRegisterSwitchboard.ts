import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  createObj,
  deployContractWithArgs,
  getChainRoleHash,
  getInstance,
  getRoleHash,
  getSwitchboardAddress,
  storeAddresses,
} from "./utils";
import { chainSlugs, transmitterAddress } from "../constants";
import registerSwitchBoard from "./scripts/registerSwitchboard";
import { ChainSocketAddresses, IntegrationTypes } from "../../src";
import { getSwitchboardDeployData } from "./switchboards";
import { setupFast } from "./switchboards/fastSwitchboard";

export default async function deployAndRegisterSwitchboard(
  integrationType: IntegrationTypes,
  network: string,
  capacitorType: number,
  maxPacketLength: number,
  remoteChain: string,
  signer: SignerWithAddress,
  sourceConfig: ChainSocketAddresses
) {
  try {
    const remoteChainSlug = chainSlugs[remoteChain];

    const result = getOrStoreSwitchboardAddress(
      chainSlugs[remoteChain],
      integrationType,
      sourceConfig
    );
    const { contractName, args, path } = getSwitchboardDeployData(
      integrationType,
      network,
      remoteChain,
      sourceConfig["Socket"],
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
        [
          "integrations",
          chainSlugs[remoteChain],
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

      await storeAddresses(sourceConfig, chainSlugs[network]);

      const grantee = signer.address;
      const tx = await switchboard
        .connect(signer)
        ["grantBatchRole(bytes32[],address[])"](
          [
            getRoleHash("TRIP_ROLE"),
            getRoleHash("UNTRIP_ROLE"),
            getRoleHash("GOVERNANCE_ROLE"),
            getRoleHash("WITHDRAW_ROLE"),
            getRoleHash("RESCUE_ROLE"),
          ],
          [grantee, grantee, grantee, grantee, grantee]
        );
      console.log(`Assigned switchboard batch roles to ${grantee}: ${tx.hash}`);
    } else {
      switchboard = await getInstance(contractName, result.switchboardAddr);
    }

    sourceConfig = await registerSwitchBoard(
      switchboard.address,
      remoteChainSlug,
      capacitorType,
      maxPacketLength,
      signer,
      integrationType,
      sourceConfig
    );
    await storeAddresses(sourceConfig, chainSlugs[network]);

    if (
      contractName === "FastSwitchboard" ||
      contractName === "OptimisticSwitchboard"
    ) {
      const grantee = transmitterAddress[network];
      const tx = await switchboard
        .connect(signer)
        ["grantBatchRole(bytes32[],address[])"](
          [
            getChainRoleHash("TRIP_ROLE", chainSlugs[remoteChain]),
            getChainRoleHash("UNTRIP_ROLE", chainSlugs[remoteChain]),
            getChainRoleHash("GAS_LIMIT_UPDATER_ROLE", chainSlugs[remoteChain]),
          ],
          [grantee, grantee, grantee]
        );
      console.log(
        `Assigned default switchboard batch roles to ${grantee}: ${tx.hash}`
      );
      await tx.wait();
    }

    if (contractName === "FastSwitchboard") {
      await setupFast(
        switchboard,
        chainSlugs[remoteChain],
        network,
        remoteChain,
        signer
      );
    } else if (contractName !== "OptimisticSwitchboard") {
      const grantLimitUpdaterRoleTxn = await switchboard
        .connect(signer)
        ["grantRole(bytes32,address)"](
          getRoleHash("GAS_LIMIT_UPDATER_ROLE"),
          transmitterAddress[network]
        );
      console.log(
        `Setting gas limit updater role for native switchboard: ${grantLimitUpdaterRoleTxn.hash}`
      );
      await grantLimitUpdaterRoleTxn.wait();
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

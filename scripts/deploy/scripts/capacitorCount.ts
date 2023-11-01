import { ContractFactory } from "ethers";
import { network, ethers, run } from "hardhat";

import { DeployParams, getOrDeploy, storeAddresses } from "../utils";

import {
  CORE_CONTRACTS,
  ChainSocketAddresses,
  DeploymentMode,
  ChainSlugToKey,
  version,
  DeploymentAddresses,
  getAllAddresses,
  ChainSlug,
  IntegrationTypes,
} from "../../../src";
import deploySwitchboards from "./deploySwitchboard";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { socketOwner, executionManagerVersion, mode, chains } from "../config";
import {
  getProviderFromChainSlug,
  maxAllowedPacketLength,
} from "../../constants";

const main = async (
  srcChains: ChainSlug[],
  dstChains: ChainSlug[],
  integrationTypes: IntegrationTypes[]
) => {
  try {
    let addresses: DeploymentAddresses;
    try {
      addresses = getAllAddresses(mode);
    } catch (error) {
      addresses = {} as DeploymentAddresses;
    }
    let srcChainSlugs = srcChains ?? chains;

    await Promise.all(
      srcChainSlugs.map(async (chainSlug) => {
        let integrations = addresses[chainSlug as ChainSlug]?.integrations;
        if (!integrations) return;

        let siblingChains = dstChains ?? Object.keys(integrations);

        await Promise.all(
          siblingChains.map(async (siblingChain) => {
            let siblingIntegrations =
              integrations?.[Number(siblingChain) as ChainSlug];
            if (!siblingIntegrations) return;
            let integrationTypesArray =
              integrationTypes ?? Object.keys(siblingIntegrations);

            await Promise.all(
              integrationTypesArray.map(async (integrationType) => {
                let integration =
                  siblingIntegrations?.[integrationType as IntegrationTypes];
                if (!integration) return;
                let capacitor = integration.capacitor;
                if (!capacitor) return;
                let provider = getProviderFromChainSlug(chainSlug as ChainSlug);
                let Contract = await ethers.getContractFactory(
                  "SingleCapacitor"
                );
                let instance = Contract.attach(capacitor).connect(provider);
                let result = await instance.getNextPacketToBeSealed();
                console.log(
                  chainSlug,
                  " ",
                  Number(siblingChain),
                  " ",
                  integrationType,
                  " ",
                  result[1].toNumber(),
                  " ",
                  result[0].toString()
                );
              })
            );
          })
        );
      })
    );
  } catch (error) {
    console.log(error);
  }
};

// let srcChains;
// let dstChains;
let integrationTypes;

let srcChains = [ChainSlug.OPTIMISM_GOERLI];
let dstChains = [ChainSlug.ARBITRUM_GOERLI];
// let integrationTypes = [IntegrationTypes.fast2];

main(srcChains, dstChains, integrationTypes);

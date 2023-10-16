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

const main = async (srcChains: ChainSlug[], dstChains: ChainSlug[]) => {
  try {
    let addresses: DeploymentAddresses;
    try {
      addresses = getAllAddresses(mode);
    } catch (error) {
      addresses = {} as DeploymentAddresses;
    }
    let srcChainSlugs = srcChains ?? chains;
    let data: any[] = [];
    await Promise.all(
      srcChainSlugs.map(async (chainSlug) => {
        let fastSwitchboardAddress =
          addresses[chainSlug as ChainSlug]?.FastSwitchboard2;
        if (!fastSwitchboardAddress) return;

        let siblingChains = dstChains ?? chains.filter((s) => chainSlug !== s);

        await Promise.all(
          siblingChains.map(async (siblingChain) => {
            let provider = getProviderFromChainSlug(chainSlug as ChainSlug);
            let Contract = await ethers.getContractFactory("FastSwitchboard");
            let instance = Contract.attach(fastSwitchboardAddress).connect(
              provider
            );
            // console.log(instance);÷\
            let result = await instance["totalWatchers(uint32)"](siblingChain);
            // console.log(result);
            data.push({
              chainSlug,
              siblingChain,
              totalWatchers: result.toNumber(),
            });
          })
        );
      })
    );
    console.table(data);
  } catch (error) {
    console.log(error);
  }
};

// let srcChains;
// let dstChains;

let srcChains = [ChainSlug.ARBITRUM_GOERLI];
let dstChains = [ChainSlug.AEVO_TESTNET];
// let integrationTypes = [IntegrationTypes.fast2];

main(srcChains, dstChains);

import { ContractFactory, utils } from "ethers";
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
    let dstChainSlugs = dstChains ?? chains;

    let data: any[] = [];
    await Promise.all(
      srcChainSlugs.map(async (chainSlug) => {
        let fastSwitchboardAddress =
          addresses[chainSlug as ChainSlug]?.FastSwitchboard;
          // addresses[chainSlug as ChainSlug]?.FastSwitchboard2;
        if (!fastSwitchboardAddress) return;

        let siblingChains = dstChainSlugs.filter((s) => chainSlug !== s);

        await Promise.all(
          siblingChains.map(async (siblingChain) => {
            let provider = getProviderFromChainSlug(chainSlug as ChainSlug);
            let Contract = await ethers.getContractFactory("FastSwitchboard");
            let instance = Contract.attach(fastSwitchboardAddress).connect(
              provider
            );
            // console.log(instance);÷\
            let result = await instance["totalWatchers(uint32)"](siblingChain);

            let digest = utils.keccak256(
              utils.defaultAbiCoder.encode(
                ["address", "uint32", "bytes32", "uint256"],
                // ["address", "uint32", "bytes32", "uint256", "bytes32"],
                [
                  fastSwitchboardAddress?.toLowerCase(),
                  chainSlug,
                  "0x00aa36a841667f3df292b3ed613d66b39dd2d8327d2ef5a80000000000000000",
                  0,
                  // "0x80b582422ec90d907e218c10e879241ddf21d3274e03÷18de902f4abece0ac6c5"
                ]
              )
            );

            // console.log(result);
            data.push({
              chainSlug,
              siblingChain,
              totalWatchers: result.toNumber(),
              digest,
              fastSwitchboardAddress,
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

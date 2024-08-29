import { utils } from "ethers";
import { ethers } from "hardhat";

import { DeploymentAddresses, getAllAddresses, ChainSlug } from "../../../src";
import { mode, chains } from "../config/config";
import { getProviderFromChainSlug } from "../../constants";

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
        if (!fastSwitchboardAddress) return;

        let siblingChains = dstChainSlugs.filter((s) => chainSlug !== s);

        await Promise.all(
          siblingChains.map(async (siblingChain) => {
            let provider = getProviderFromChainSlug(chainSlug as ChainSlug);
            let Contract = await ethers.getContractFactory("FastSwitchboard");
            let instance = Contract.attach(fastSwitchboardAddress).connect(
              provider
            );
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

let srcChains = [ChainSlug.ARBITRUM_GOERLI];
let dstChains = [ChainSlug.AEVO_TESTNET];
main(srcChains, dstChains);

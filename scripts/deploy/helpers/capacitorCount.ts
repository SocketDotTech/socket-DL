import { utils } from "ethers";
import { ethers } from "hardhat";

import {
  version,
  DeploymentAddresses,
  getAllAddresses,
  ChainSlug,
  IntegrationTypes,
} from "../../../src";
import { mode, chains } from "../config/config";
import { getProviderFromChainSlug } from "../../constants";
import { encodePacketId } from "../utils/packetId";

const main = async (
  srcChains: ChainSlug[],
  dstChains: ChainSlug[],
  integrationTypes: IntegrationTypes[]
) => {
  try {
    let data: any[] = [];

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
                let nextSealedPacket = await instance.getNextPacketToBeSealed();
                let lastFilledPacket = await instance.getLastFilledPacket();

                let digest = utils.keccak256(
                  utils.defaultAbiCoder.encode(
                    ["bytes32", "uint32", "bytes32", "bytes32"],
                    [
                      utils.id(version[mode]),
                      siblingChain,
                      encodePacketId(
                        chainSlug,
                        capacitor,
                        nextSealedPacket[1].toNumber()
                      ),
                      nextSealedPacket[0].toString(),
                    ]
                  )
                );
                data.push({
                  chainSlug,
                  siblingChain,
                  integrationType,
                  lastFilledPacket: lastFilledPacket.toNumber(),
                  nextSealedPacketCount: nextSealedPacket[1].toNumber(),
                  root: nextSealedPacket[0].toString(),
                  digest: digest,
                });
              })
            );
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
let integrationTypes;

let srcChains = [ChainSlug.OPTIMISM_GOERLI];
let dstChains = [ChainSlug.ARBITRUM_GOERLI];
// let integrationTypes = [IntegrationTypes.fast2];

main(srcChains, dstChains, integrationTypes);

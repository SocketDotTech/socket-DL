// TODO: This is duplicate from socket-dl and should be in its own module
import addresses from "../deployments/addresses.json";
import { ChainSlug, DeploymentAddresses, IntegrationTypes } from "./types";

const deploymentAddresses = addresses as DeploymentAddresses;

function getSwitchboardAddress(
  srcChainSlug: ChainSlug,
  dstChainSlug: ChainSlug,
  integration: IntegrationTypes
) {
  const switchboardAddress =
    deploymentAddresses[srcChainSlug]?.["integrations"]?.[dstChainSlug]?.[
      integration
    ]?.switchboard;

  if (!switchboardAddress) {
    throw new Error(
      `Switchboard address for ${srcChainSlug}-${dstChainSlug}-${integration} not found`
    );
  }

  return switchboardAddress;
}

function getCapacitorAddress(
  srcChainSlug: ChainSlug,
  dstChainSlug: ChainSlug,
  integration: IntegrationTypes
) {
  const capacitorAddress =
    deploymentAddresses[srcChainSlug]?.["integrations"]?.[dstChainSlug]?.[
      integration
    ]?.capacitor;

  if (!capacitorAddress) {
    throw new Error(
      `Capacitor address for ${srcChainSlug}-${dstChainSlug}-${integration} not found`
    );
  }

  return capacitorAddress;
}

function getDeCapacitorAddress(
  srcChainSlug: ChainSlug,
  dstChainSlug: ChainSlug,
  integration: IntegrationTypes
) {
  const deCapacitorAddress =
    deploymentAddresses[srcChainSlug]?.["integrations"]?.[dstChainSlug]?.[
      integration
    ]?.capacitor;

  if (!deCapacitorAddress) {
    throw new Error(
      `De Capacitor address for ${srcChainSlug}-${dstChainSlug}-${integration} not found`
    );
  }

  return deCapacitorAddress;
}

export {
  deploymentAddresses,
  getSwitchboardAddress,
  getCapacitorAddress,
  getDeCapacitorAddress,
};

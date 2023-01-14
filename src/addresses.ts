// TODO: This is duplicate from socket-dl and should be in its own module
import addresses from "../deployments/addresses.json";
import { ChainId, DeploymentAddresses, IntegrationTypes } from "./types";

const deploymentAddresses = addresses as DeploymentAddresses;

function getSwitchboardAddress(
  srcChainId: ChainId,
  dstChainId: ChainId,
  integration: IntegrationTypes
) {
  const switchboardAddress =
    deploymentAddresses[srcChainId]?.["integrations"]?.[dstChainId]?.[
      integration
    ]?.switchboard;

  if (!switchboardAddress) {
    throw new Error(
      `Switchboard adddess for ${srcChainId}-${dstChainId}-${integration} not found`
    );
  }

  return switchboardAddress;
}

function getCapacitorAddress(
  srcChainId: ChainId,
  dstChainId: ChainId,
  integration: IntegrationTypes
) {
  const capacitorAddress =
    deploymentAddresses[srcChainId]?.["integrations"]?.[dstChainId]?.[
      integration
    ]?.capacitor;

  if (!capacitorAddress) {
    throw new Error(
      `Capacitor address for ${srcChainId}-${dstChainId}-${integration} not found`
    );
  }

  return capacitorAddress;
}

function getDeCapacitorAddress(
  srcChainId: ChainId,
  dstChainId: ChainId,
  integration: IntegrationTypes
) {
  const deCapacitorAddress =
    deploymentAddresses[srcChainId]?.["integrations"]?.[dstChainId]?.[
      integration
    ]?.capacitor;

  if (!deCapacitorAddress) {
    throw new Error(
      `De Capacitor address for ${srcChainId}-${dstChainId}-${integration} not found`
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

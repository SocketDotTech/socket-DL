// TODO: This is duplicate from socket-dl and should be in its own module
import addresses from "../deployments/addresses.json";
import { ChainId, DeploymentAddresses, IntegrationTypes } from "./types";

const deploymentAddresses = addresses as DeploymentAddresses;

function getNotaryAddress(
  srcChainId: ChainId,
  dstChainId: ChainId,
  integration: IntegrationTypes
) {
  const notaryAddress =
    deploymentAddresses[srcChainId]?.["integrations"]?.[dstChainId]?.[
      integration
    ]?.notary;

  if (!notaryAddress) {
    throw new Error(
      `Notary adddess for ${srcChainId}-${dstChainId}-${integration} not found`
    );
  }

  return notaryAddress;
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

function getDeCapacitorAddress(srcChainId: ChainId) {
  const deCapacitorAddress = deploymentAddresses[srcChainId]?.SingleDecapacitor;

  if (!deCapacitorAddress) {
    throw new Error(`De Capacitor address for ${srcChainId} not found`);
  }

  return deCapacitorAddress;
}

export {
  deploymentAddresses,
  getNotaryAddress,
  getCapacitorAddress,
  getDeCapacitorAddress,
};

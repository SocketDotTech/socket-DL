// TODO: This is duplicate from socket-dl and should be in its own module
import addresses from "../deployments/addresses.json";
import { ChainId, DeploymentAddresses, IntegrationTypes } from "./types";

const deploymentAddresses = addresses as DeploymentAddresses;

function getNotaryAddress(
  srcChainId: ChainId,
  dstChainId: ChainId,
  integration: IntegrationTypes
) {
  const notaryAddress = deploymentAddresses[srcChainId]?.["integrations"]?.[dstChainId]?.[integration]?.notary;

  if (!notaryAddress) {
    throw new Error(`Notary adddess for ${srcChainId}-${dstChainId}-${integration} not found`);
  }

  return notaryAddress;
}

function getAccumAddress(
  srcChainId: ChainId,
  dstChainId: ChainId,
  integration: IntegrationTypes
) {
  const accumAddress = deploymentAddresses[srcChainId]?.["integrations"]?.[dstChainId]?.[integration]?.accum;

  if (!accumAddress) {
    throw new Error(
      `Accumulator address for ${srcChainId}-${dstChainId}-${integration} not found`
    );
  }

  return accumAddress;
}

function getDeAccumAddress(srcChainId: ChainId) {
  const deAccumAddress = deploymentAddresses[srcChainId]?.SingleDeaccum;

  if (!deAccumAddress) {
    throw new Error(
      `De Accumulator address for ${srcChainId} not found`
    );
  }

  return deAccumAddress;
}

export {
  deploymentAddresses,
  getNotaryAddress,
  getAccumAddress,
  getDeAccumAddress,
};

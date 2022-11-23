// TODO: This is duplicate from socket-dl and should be in its own module
import addresses from "../deployments/addresses.json";
import { ChainId, DeploymentAddresses } from "./types";

const deploymentAddresses = addresses as DeploymentAddresses;

function getNotaryAddress(chainId: ChainId) {
  const notaryAddress = deploymentAddresses[chainId]?.notary;

  if (!notaryAddress) {
    throw new Error(`Notary adddess for ${chainId} not found`);
  }

  return notaryAddress;
}

function getAccumAddress(
  srcChainId: ChainId,
  dstChainId: ChainId,
  fast: boolean
) {
  const accumAddress = fast
    ? deploymentAddresses[srcChainId]?.fastAccum[dstChainId]
    : deploymentAddresses[srcChainId]?.slowAccum[dstChainId];

  if (!accumAddress) {
    throw new Error(
      `Accumulator address for ${srcChainId}-${dstChainId} not found`
    );
  }

  return accumAddress;
}

function getDeAccumAddress(srcChainId: ChainId, dstChainId: ChainId) {
  const deAccumAddress = deploymentAddresses[dstChainId]?.deaccum[srcChainId];

  if (!deAccumAddress) {
    throw new Error(
      `De Accumulator address for ${srcChainId}-${dstChainId} not found`
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

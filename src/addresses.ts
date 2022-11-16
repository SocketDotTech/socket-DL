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
    throw new Error(`Accum address for ${srcChainId}-${dstChainId} not found`);
  }

  return accumAddress;
}

export { deploymentAddresses, getNotaryAddress, getAccumAddress };

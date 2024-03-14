// TODO: This is duplicate from socket-dl and should be in its own module
import {
  ChainSlug,
  ChainSocketAddresses,
  DeploymentMode,
  IntegrationTypes,
  DeploymentAddresses,
} from "./";

import dev_addresses from "../deployments/dev_addresses.json";
import prod_addresses from "../deployments/prod_addresses.json";
import surge_addresses from "../deployments/surge_addresses.json";

function getAllAddresses(mode: DeploymentMode): DeploymentAddresses {
  let addresses: DeploymentAddresses | undefined;

  switch (mode) {
    case DeploymentMode.DEV:
      addresses = dev_addresses as unknown as DeploymentAddresses;
      break;
    case DeploymentMode.PROD:
      addresses = prod_addresses as unknown as DeploymentAddresses;
      break;
    case DeploymentMode.SURGE:
      addresses = surge_addresses as unknown as DeploymentAddresses;
      break;
    default:
      throw new Error("No Mode Provided");
  }

  if (!addresses) throw new Error("addresses not found");
  return addresses;
}

function getAddresses(
  srcChainSlug: ChainSlug,
  mode: DeploymentMode
): ChainSocketAddresses {
  let addresses: ChainSocketAddresses | undefined =
    getAllAddresses(mode)[srcChainSlug];
  if (!addresses) throw new Error("addresses not found");
  return addresses;
}

function getSwitchboardAddress(
  srcChainSlug: ChainSlug,
  dstChainSlug: ChainSlug,
  integration: IntegrationTypes,
  mode: DeploymentMode
) {
  const addr = getAddresses(srcChainSlug, mode);
  const switchboardAddress =
    addr?.["integrations"]?.[dstChainSlug]?.[integration]?.switchboard;

  if (!switchboardAddress) {
    throw new Error(
      `Switchboard address for ${srcChainSlug}-${dstChainSlug}-${integration} not found`
    );
  }

  return switchboardAddress;
}

function getSwitchboardAddressFromAllAddresses(
  allAddresses: DeploymentAddresses,
  srcChainSlug: ChainSlug,
  dstChainSlug: ChainSlug,
  integration: IntegrationTypes
) {
  const addr = allAddresses[srcChainSlug];
  if (!addr) {
    throw new Error(`Addresses for ${srcChainSlug} not found`);
  }
  const switchboardAddress =
    addr?.["integrations"]?.[dstChainSlug]?.[integration]?.switchboard;

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
  integration: IntegrationTypes,
  mode: DeploymentMode
) {
  const addr = getAddresses(srcChainSlug, mode);
  const capacitorAddress =
    addr?.["integrations"]?.[dstChainSlug]?.[integration]?.capacitor;

  if (!capacitorAddress) {
    throw new Error(
      `Capacitor address for ${srcChainSlug}-${dstChainSlug}-${integration} not found`
    );
  }

  return capacitorAddress;
}

function getCapacitorAddressFromAllAddresses(
  allAddresses: DeploymentAddresses,
  srcChainSlug: ChainSlug,
  dstChainSlug: ChainSlug,
  integration: IntegrationTypes,
) {
  const addr = allAddresses[srcChainSlug];
  if (!addr) {
    throw new Error(`Addresses for ${srcChainSlug} not found`);
  }
  const capacitorAddress =
    addr?.["integrations"]?.[dstChainSlug]?.[integration]?.capacitor;

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
  integration: IntegrationTypes,
  mode: DeploymentMode
) {
  const addr = getAddresses(srcChainSlug, mode);
  const deCapacitorAddress =
    addr?.["integrations"]?.[dstChainSlug]?.[integration]?.capacitor;

  if (!deCapacitorAddress) {
    throw new Error(
      `De Capacitor address for ${srcChainSlug}-${dstChainSlug}-${integration} not found`
    );
  }

  return deCapacitorAddress;
}

function getDeCapacitorAddressFromAllAddresses(
  allAddresses: DeploymentAddresses,
  srcChainSlug: ChainSlug,
  dstChainSlug: ChainSlug,
  integration: IntegrationTypes,
) {
  const addr = allAddresses[srcChainSlug];
  if (!addr) {
    throw new Error(`Addresses for ${srcChainSlug} not found`);
  }
  const deCapacitorAddress =
    addr?.["integrations"]?.[dstChainSlug]?.[integration]?.capacitor;

  if (!deCapacitorAddress) {
    throw new Error(
      `De Capacitor address for ${srcChainSlug}-${dstChainSlug}-${integration} not found`
    );
  }

  return deCapacitorAddress;
}

export {
  getSwitchboardAddress,
  getCapacitorAddress,
  getDeCapacitorAddress,
  getAddresses,
  getAllAddresses,
  getCapacitorAddressFromAllAddresses,
  getDeCapacitorAddressFromAllAddresses,
  getSwitchboardAddressFromAllAddresses,
};

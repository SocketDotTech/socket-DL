import { ChainId, IntegrationTypes } from "../../../src";

function getSwitchboardAddress(chainId: ChainId | string, integrationType: IntegrationTypes, config: any) {
  return config?.["integrations"]?.[chainId]?.[integrationType]?.["switchboard"];
}

function getCapacitorAddress(chainId: ChainId, integrationType: IntegrationTypes, config: any) {
  return config?.["integrations"]?.[chainId]?.[integrationType]?.["capacitor"];
}

function getDecapacitorAddress(chainId: ChainId, integrationType: IntegrationTypes, config: any) {
  return config?.["integrations"]?.[chainId]?.[integrationType]?.["decapacitor"];
}

export {
  getSwitchboardAddress,
  getCapacitorAddress,
  getDecapacitorAddress
};


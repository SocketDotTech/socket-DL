import {
  ChainSlug,
  ChainSocketAddresses,
  IntegrationTypes,
  Integrations,
} from "../../../src";

function getSwitchboardAddress(
  chainSlug: ChainSlug | string,
  integrationType: IntegrationTypes,
  config: any
) {
  if (integrationType === IntegrationTypes.fast) {
    return config?.["FastSwitchboard"];
  } else if (integrationType === IntegrationTypes.fast2) {
    return config?.["FastSwitchboard2"];
  } else if (integrationType === IntegrationTypes.optimistic) {
    return config?.["OptimisticSwitchboard"];
  } else
    return config?.["integrations"]?.[chainSlug]?.[integrationType]?.[
      "switchboard"
    ];
}

function getCapacitorAddress(
  chainSlug: ChainSlug,
  integrationType: IntegrationTypes,
  config: any
) {
  return config?.["integrations"]?.[chainSlug]?.[integrationType]?.[
    "capacitor"
  ];
}

function getDecapacitorAddress(
  chainSlug: ChainSlug,
  integrationType: IntegrationTypes,
  config: any
) {
  return config?.["integrations"]?.[chainSlug]?.[integrationType]?.[
    "decapacitor"
  ];
}

export const getSiblings = (addresses: ChainSocketAddresses): ChainSlug[] => {
  try {
    const integrations: Integrations = addresses.integrations;
    if (!integrations) return [] as ChainSlug[];

    return Object.keys(integrations).map(
      (chainSlug) => parseInt(chainSlug) as ChainSlug
    );
  } catch (error) {
    return [] as ChainSlug[];
  }
};

export { getSwitchboardAddress, getCapacitorAddress, getDecapacitorAddress };

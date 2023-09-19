import { ChainSlug, IntegrationTypes } from "../../../src";

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

export { getSwitchboardAddress, getCapacitorAddress, getDecapacitorAddress };

import {
  ChainSlug,
  getAddresses,
  Integrations,
  DeploymentMode,
  ChainSocketAddresses,
  ChainAddresses,
} from "../../src";

export const getSiblings = (
  deploymentMode: DeploymentMode,
  chainSlug: ChainSlug
): ChainSlug[] => {
  try {
    const integrations: Integrations = getAddresses(
      chainSlug,
      deploymentMode
    ).integrations;
    if (!integrations) return [] as ChainSlug[];

    return Object.keys(integrations).map(
      (chainSlug) => parseInt(chainSlug) as ChainSlug
    );
  } catch (error) {
    return [] as ChainSlug[];
  }
};

export const getSiblingsFromAddresses = (
  addresses: ChainSocketAddresses
): ChainSlug[] => {
  try {
    const integrations: Integrations = addresses.integrations;
    if (!integrations) return [] as ChainSlug[];

    const chains = [];
    Object.keys(integrations).map((chainSlug) => {
      const integration: ChainAddresses = integrations[chainSlug];
      if (integration.FAST) chains.push(parseInt(chainSlug) as ChainSlug);
    });

    return chains;
  } catch (error) {
    return [] as ChainSlug[];
  }
};

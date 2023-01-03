import { ChainId, IntegrationTypes } from "../../../src";

function getVerifierAddress(verifier: string, chainId: ChainId, config: any) {
  return verifier === "Verifier" ? config[verifier] : config["integrations"]?.[chainId]?.[IntegrationTypes.nativeIntegration]?.["verifier"];
}

function getNotaryAddress(notary: string, chainId: ChainId, config: any) {
  return notary === "AdminNotary" ? config[notary] : config["integrations"]?.[chainId]?.[IntegrationTypes.nativeIntegration]?.["notary"];
}

function getAccumAddress(chainId: ChainId, integrationType: string, config: any) {
  return config["integrations"]?.[chainId]?.[integrationType]?.["accum"];
}

export {
  getNotaryAddress,
  getAccumAddress,
  getVerifierAddress
};


import { ChainId } from "../types";

function getVerifierAddress(verifier: string, chainId: ChainId, config: any) {
  return verifier === "Verifier" ? config[verifier] : config["integrations"]?.[chainId]?.["NATIVE"]?.["verifier"];
}

function getNotaryAddress(notary: string, chainId: ChainId, config: any) {
  return notary === "AdminNotary" ? config[notary] : config["integrations"]?.[chainId]?.["NATIVE"]?.["notary"];
}

export {
  getNotaryAddress,
  getVerifierAddress
};


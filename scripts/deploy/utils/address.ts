import { nativeBridgeIntegration } from "../../constants";
import { ChainId } from "../types";

function getVerifierAddress(verifier: string, chainId: ChainId, config: any) {
  return verifier === "Verifier" ? config[verifier] : config["integrations"]?.[chainId]?.[nativeBridgeIntegration]?.["verifier"];
}

function getNotaryAddress(notary: string, chainId: ChainId, config: any) {
  return notary === "AdminNotary" ? config[notary] : config["integrations"]?.[chainId]?.[nativeBridgeIntegration]?.["notary"];
}

export {
  getNotaryAddress,
  getVerifierAddress
};


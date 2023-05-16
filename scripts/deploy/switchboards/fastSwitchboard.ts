import { timeout } from "../../constants";
import { CORE_CONTRACTS, chainKeyToSlug } from "../../../src";

export const fastSwitchboard = (
  network: string,
  socketAddress: string,
  sigVerifierAddress: string,
  signerAddress: string
) => {
  return {
    contractName: CORE_CONTRACTS.FastSwitchboard,
    args: [
      signerAddress,
      socketAddress,
      chainKeyToSlug[network],
      timeout[network],
      sigVerifierAddress,
    ],
    path: "contracts/switchboard/default-switchboards/FastSwitchboard.sol",
  };
};

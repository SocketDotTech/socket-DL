import { CORE_CONTRACTS, chainKeyToSlug } from "../../../src";
import { timeout } from "../../constants";

export const optimisticSwitchboard = (
  network: string,
  socketAddress: string,
  sigVerifierAddress: string,
  signerAddress: string
) => {
  return {
    contractName: CORE_CONTRACTS.OptimisticSwitchboard,
    args: [
      signerAddress,
      socketAddress,
      chainKeyToSlug[network],
      timeout[network],
      sigVerifierAddress,
    ],
    path: "contracts/switchboard/default-switchboards/OptimisticSwitchboard.sol",
  };
};

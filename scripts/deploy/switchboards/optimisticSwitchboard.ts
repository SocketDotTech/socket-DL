import { CORE_CONTRACTS, ChainSlug } from "../../../src";
import { timeout } from "../../constants";

export const optimisticSwitchboard = (
  chainSlug: ChainSlug,
  socketAddress: string,
  sigVerifierAddress: string,
  signerAddress: string
) => {
  return {
    contractName: CORE_CONTRACTS.OptimisticSwitchboard,
    args: [
      signerAddress,
      socketAddress,
      chainSlug,
      timeout(chainSlug),
      sigVerifierAddress,
    ],
    path: "contracts/switchboard/default-switchboards/OptimisticSwitchboard.sol",
  };
};

import { CORE_CONTRACTS, ChainSlug } from "../../../src";
import { timeout } from "../../constants";

export const optimisticSwitchboard = (
  chainSlug: ChainSlug,
  socketAddress: string,
  sigVerifierAddress: string,
  owner: string
) => {
  return {
    contractName: CORE_CONTRACTS.OptimisticSwitchboard,
    args: [
      owner,
      socketAddress,
      chainSlug,
      timeout(chainSlug),
      sigVerifierAddress,
    ],
    path: "contracts/switchboard/default-switchboards/OptimisticSwitchboard.sol",
  };
};

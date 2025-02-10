import { timeout } from "../../constants";
import { CORE_CONTRACTS, ChainSlug } from "../../../src";

export const fastSwitchboard = (
  chainSlug: ChainSlug,
  socketAddress: string,
  sigVerifierAddress: string,
  owner: string
) => {
  return {
    contractName: CORE_CONTRACTS.FastSwitchboard,
    args: [
      owner,
      socketAddress,
      chainSlug,
      timeout(chainSlug),
      sigVerifierAddress,
    ],
    path: "contracts/switchboard/default-switchboards/FastSwitchboard.sol",
  };
};

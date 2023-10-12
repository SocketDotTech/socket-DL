import { timeout } from "../../constants";
import { CORE_CONTRACTS, ChainSlug } from "../../../src";

export const fastSwitchboard = (
  chainSlug: ChainSlug,
  socketAddress: string,
  sigVerifierAddress: string,
  signerAddress: string
) => {
  return {
    contractName: CORE_CONTRACTS.FastSwitchboard,
    args: [
      signerAddress,
      socketAddress,
      chainSlug,
      timeout[chainSlug],
      sigVerifierAddress,
    ],
    path: "contracts/switchboard/default-switchboards/FastSwitchboard.sol",
  };
};

import { CORE_CONTRACTS, chainKeyToSlug } from "../../../src";
import { timeout } from "../../constants";

export const optimisticSwitchboard = (
  network: string,
  socketAddress: string,
  oracleAddress: string,
  signerAddress: string
) => {
  return {
    contractName: CORE_CONTRACTS.OptimisticSwitchboard,
    args: [
      signerAddress,
      socketAddress,
      oracleAddress,
      chainKeyToSlug[network],
      timeout[network],
    ],
    path: "contracts/switchboard/default-switchboards/OptimisticSwitchboard.sol",
  };
};

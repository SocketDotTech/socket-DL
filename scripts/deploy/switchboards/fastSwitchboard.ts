import { timeout } from "../../constants";
import { CORE_CONTRACTS, chainKeyToSlug } from "../../../src";

export const fastSwitchboard = (
  network: string,
  socketAddress: string,
  oracleAddress: string,
  signerAddress: string
) => {
  return {
    contractName: CORE_CONTRACTS.FastSwitchboard,
    args: [
      signerAddress,
      socketAddress,
      oracleAddress,
      chainKeyToSlug[network],
      timeout[network],
    ],
    path: "contracts/switchboard/default-switchboards/FastSwitchboard.sol",
  };
};

import { chainSlugs, timeout } from "../../constants";

export const optimisticSwitchboard = (
  network: string,
  socketAddress: string,
  oracleAddress: string,
  signerAddress: string
) => {
  return {
    contractName: "OptimisticSwitchboard",
    args: [
      signerAddress,
      socketAddress,
      oracleAddress,
      chainSlugs[network],
      timeout[network],
    ],
    path: "contracts/switchboard/default-switchboards/OptimisticSwitchboard.sol",
  };
};

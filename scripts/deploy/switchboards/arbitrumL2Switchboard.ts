import { chainKeyToSlug } from "../../../src";

const initiateGasLimit = 300000;
const confirmGasLimit = 300000;

export const arbitrumL2Switchboard = (
  network: string,
  socketAddress: string,
  oracleAddress: string,
  signerAddress: string
) => {
  return {
    contractName: "ArbitrumL2Switchboard",
    args: [
      chainKeyToSlug[network],
      initiateGasLimit,
      signerAddress,
      socketAddress,
      oracleAddress,
    ],
    path: "contracts/switchboard/native/ArbitrumL2Switchboard.sol",
  };
};

import { constants } from "ethers";

const executionOverhead = 300000;
const initiateGasLimit = 300000;
const confirmGasLimit = 300000;

export const arbitrumL2Switchboard = (
  oracleAddress: string,
  signerAddress: string
) => {
  return {
    contractName: "ArbitrumL2Switchboard",
    args: [
      confirmGasLimit,
      initiateGasLimit,
      executionOverhead,
      constants.AddressZero,
      signerAddress,
      oracleAddress,
    ],
    path: "contracts/switchboard/native/ArbitrumL2Switchboard.sol",
  };
};

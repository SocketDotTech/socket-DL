import { constants } from "ethers";

const executionOverhead = 300000;
const initiateGasLimit = 300000;
const confirmGasLimit = 300000;
const receiveGasLimit = 300000;

export const optimismSwitchboard = (
  oracleAddress: string,
  signerAddress: string
) => {
  return {
    contractName: "OptimismSwitchboard",
    args: [
      receiveGasLimit,
      confirmGasLimit,
      initiateGasLimit,
      executionOverhead,
      constants.AddressZero,
      signerAddress,
      oracleAddress,
    ],
    path: "contracts/switchboard/native/OptimismSwitchboard.sol",
  };
};

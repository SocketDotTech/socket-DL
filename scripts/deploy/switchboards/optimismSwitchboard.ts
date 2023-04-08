import { constants } from "ethers";
import { bridgeConsts } from "../../constants";

const executionOverhead = 300000;
const initiateGasLimit = 300000;
const confirmGasLimit = 300000;
const receiveGasLimit = 300000;

export const optimismSwitchboard = async (
  network: string,
  oracleAddress: string,
  signerAddress: string
) => {
  let crossDomainMessengerAddress: string =
    bridgeConsts.crossDomainMessenger[network];

  if (!crossDomainMessengerAddress || crossDomainMessengerAddress == "") {
    throw new Error("Wrong network - crossDomainMessengerAddress is null");
  }

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
      crossDomainMessengerAddress,
    ],
    path: "contracts/switchboard/native/OptimismSwitchboard.sol",
  };
};

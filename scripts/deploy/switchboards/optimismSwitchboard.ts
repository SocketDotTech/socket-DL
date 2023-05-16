import { chainKeyToSlug } from "../../../src";
import { bridgeConsts } from "../../constants";

const initiateGasLimit = 300000;
const confirmGasLimit = 300000;
const receiveGasLimit = 300000;

export const optimismSwitchboard = (
  network: string,
  socketAddress: string,
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
      chainKeyToSlug[network],
      receiveGasLimit,
      confirmGasLimit,
      initiateGasLimit,
      signerAddress,
      socketAddress,
      oracleAddress,
      bridgeConsts.crossDomainMessenger[network],
    ],
    path: "contracts/switchboard/native/OptimismSwitchboard.sol",
  };
};

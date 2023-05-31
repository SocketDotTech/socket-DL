import { chainKeyToSlug } from "../../../src";
import { bridgeConsts } from "../../constants";

const receiveGasLimit = 300000;

export const optimismSwitchboard = (
  network: string,
  socketAddress: string,
  sigVerifierAddress: string,
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
      signerAddress,
      socketAddress,
      bridgeConsts.crossDomainMessenger[network],
      sigVerifierAddress,
    ],
    path: "contracts/switchboard/native/OptimismSwitchboard.sol",
  };
};

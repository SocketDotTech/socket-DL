import { ChainSlug } from "../../../src";
import { bridgeConsts } from "../../constants";

const receiveGasLimit = 300000;

export const optimismSwitchboard = (
  chainSlug: ChainSlug,
  socketAddress: string,
  sigVerifierAddress: string,
  signerAddress: string
) => {
  let crossDomainMessengerAddress: string =
    bridgeConsts.crossDomainMessenger[chainSlug];

  if (!crossDomainMessengerAddress || crossDomainMessengerAddress == "") {
    throw new Error("Wrong chainSlug - crossDomainMessengerAddress is null");
  }

  return {
    contractName: "OptimismSwitchboard",
    args: [
      chainSlug,
      receiveGasLimit,
      signerAddress,
      socketAddress,
      bridgeConsts.crossDomainMessenger[chainSlug],
      sigVerifierAddress,
    ],
    path: "contracts/switchboard/native/OptimismSwitchboard.sol",
  };
};

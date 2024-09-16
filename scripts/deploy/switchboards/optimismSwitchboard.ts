import { ChainSlug, isL1 } from "../../../src";
import { bridgeConsts } from "../../constants";

const receiveGasLimit = 300000;

export const optimismSwitchboard = (
  chainSlug: ChainSlug,
  remoteChainSlug: ChainSlug,
  socketAddress: string,
  sigVerifierAddress: string,
  owner: string
) => {
  let crossDomainMessengerAddress: string;
  if (isL1(chainSlug)) {
    crossDomainMessengerAddress =
      bridgeConsts.crossDomainMessenger[remoteChainSlug][chainSlug];
  } else {
    crossDomainMessengerAddress =
      bridgeConsts.crossDomainMessenger[chainSlug][chainSlug];
  }

  if (!crossDomainMessengerAddress || crossDomainMessengerAddress == "") {
    throw new Error("Wrong chainSlug - crossDomainMessengerAddress is null");
  }

  return {
    contractName: "OptimismSwitchboard",
    args: [
      chainSlug,
      receiveGasLimit,
      owner,
      socketAddress,
      crossDomainMessengerAddress,
      sigVerifierAddress,
    ],
    path: "contracts/switchboard/native/OptimismSwitchboard.sol",
  };
};

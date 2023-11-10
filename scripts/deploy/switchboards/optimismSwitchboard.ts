import { ChainSlug, isL1 } from "../../../src";
import { bridgeConsts } from "../../constants";

const receiveGasLimit = 300000;

export const optimismSwitchboard = (
  chainSlug: ChainSlug,
  remoteChainSlug: ChainSlug,
  socketAddress: string,
  sigVerifierAddress: string,
  signerAddress: string
) => {
  let crossDomainMessengerAddress: string;
  if (isL1(chainSlug)) {
    console.log(chainSlug, remoteChainSlug);
    crossDomainMessengerAddress =
      bridgeConsts.crossDomainMessenger[remoteChainSlug][chainSlug];
    console.log(crossDomainMessengerAddress);
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
      signerAddress,
      socketAddress,
      crossDomainMessengerAddress,
      sigVerifierAddress,
    ],
    path: "contracts/switchboard/native/OptimismSwitchboard.sol",
  };
};

import { bridgeConsts } from "../../constants";
import { ChainSlug } from "../../../src";

export const arbitrumL1Switchboard = (
  chainSlug: ChainSlug,
  socketAddress: string,
  sigVerifierAddress: string,
  owner: string
) => {
  return {
    contractName: "ArbitrumL1Switchboard",
    args: [
      chainSlug,
      bridgeConsts.inbox[chainSlug],
      owner,
      socketAddress,
      bridgeConsts.bridge[chainSlug],
      bridgeConsts.outbox[chainSlug],
      sigVerifierAddress,
    ],
    path: "contracts/switchboard/native/ArbitrumL1Switchboard.sol",
  };
};

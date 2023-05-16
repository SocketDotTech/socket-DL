import { bridgeConsts } from "../../constants";
import { chainKeyToSlug } from "../../../src";

export const arbitrumL1Switchboard = (
  network: string,
  socketAddress: string,
  sigVerifierAddress: string,
  signerAddress: string
) => {
  return {
    contractName: "ArbitrumL1Switchboard",
    args: [
      chainKeyToSlug[network],
      bridgeConsts.inbox[network],
      signerAddress,
      socketAddress,
      bridgeConsts.bridge[network],
      bridgeConsts.outbox[network],
      sigVerifierAddress,
    ],
    path: "contracts/switchboard/native/ArbitrumL1Switchboard.sol",
  };
};

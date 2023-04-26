import { bridgeConsts } from "../../constants";
import { chainKeyToSlug } from "../../../src";

const executionOverhead = 300000;
const initiateGasLimit = 300000;
const arbitrumNativeFee = 300000;

export const arbitrumL1Switchboard = (
  network: string,
  socketAddress: string,
  oracleAddress: string,
  signerAddress: string
) => {
  return {
    contractName: "ArbitrumL1Switchboard",
    args: [
      chainKeyToSlug[network],
      arbitrumNativeFee,
      initiateGasLimit,
      executionOverhead,
      bridgeConsts.inbox[network],
      signerAddress,
      socketAddress,
      oracleAddress,
      bridgeConsts.bridge[network],
      bridgeConsts.outbox[network],
    ],
    path: "contracts/switchboard/native/ArbitrumL1Switchboard.sol",
  };
};

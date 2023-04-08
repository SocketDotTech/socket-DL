import { constants } from "ethers";
import { bridgeConsts } from "../../constants";

const executionOverhead = 300000;
const initiateGasLimit = 300000;
const dynamicFees = 300000;

export const arbitrumL1Switchboard = (
  network: string,
  oracleAddress: string,
  signerAddress: string
) => {
  return {
    contractName: "ArbitrumL1Switchboard",
    args: [
      dynamicFees,
      initiateGasLimit,
      executionOverhead,
      constants.AddressZero,
      bridgeConsts.inbox[network],
      signerAddress,
      oracleAddress,
      bridgeConsts.bridge[network],
      bridgeConsts.outbox[network],
    ],
    path: "contracts/switchboard/native/ArbitrumL1Switchboard.sol",
  };
};

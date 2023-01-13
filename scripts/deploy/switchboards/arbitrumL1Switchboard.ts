import { constants } from "ethers";
import { bridgeConsts } from "../../constants";

const executionOverhead = 300000
const initialConfirmationGasLimit = 300000
const dynamicFees = 300000

export const arbitrumL1Switchboard = (
  network: string,
  socketAddress: string,
  oracleAddress: string,
  signerAddress: string
) => {
  return {
    contractName: "ArbitrumL1Switchboard",
    args: [dynamicFees, initialConfirmationGasLimit, executionOverhead, constants.AddressZero, bridgeConsts.inbox[network], signerAddress, socketAddress, oracleAddress]
  };
};

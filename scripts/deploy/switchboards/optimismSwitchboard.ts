import { constants } from "ethers";

const executionOverhead = 300000
const initialConfirmationGasLimit = 300000
const l2ReceiveGasLimit = 300000
const receivePacketGasLimit = 300000

export const optimismSwitchboard = (socketAddress: string, oracleAddress: string, signerAddress: string) => {
  return { contractName: "OptimismSwitchboard", args: [receivePacketGasLimit, l2ReceiveGasLimit, initialConfirmationGasLimit, executionOverhead, constants.AddressZero, signerAddress, socketAddress, oracleAddress] };
};

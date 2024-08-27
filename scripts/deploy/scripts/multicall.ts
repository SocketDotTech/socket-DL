import { Contract } from "ethers";

export const multicall = async (
  socketBatcher: Contract,
  calls: { target: string; callData: string }[]
): Promise<any> => {
  try {
    const result = await socketBatcher.multicall(calls);
    return result[1];
  } catch (error) {
    console.log("Error performing multicall:", error);
    throw error;
  }
};

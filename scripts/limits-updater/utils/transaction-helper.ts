import { getRpcProvider } from "./relayer.config";

export const getTransactionReceipt = async (
  transactionHash: string,
  chainSlug: number
) => {
  return await getRpcProvider(chainSlug).getTransaction(transactionHash);
};

export const isTransactionSuccessful = async (
  transactionHash: string,
  chainSlug: number
) => {
  const txReceipt: any = await getRpcProvider(chainSlug).getTransaction(
    transactionHash
  );
  return txReceipt.status == 1 ? true : false;
};

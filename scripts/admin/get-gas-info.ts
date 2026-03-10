import { createReadStream } from "fs";
import { parse } from "csv-parse";
import { ethers } from "ethers";

/**
 * Script to fetch gas limit and gas used for transactions from txs.csv
 *
 * Usage: ts-node scripts/admin/get-gas-info.ts
 */

interface TxData {
  transactionHash: string;
  chainId: string;
  chain: string;
}

interface GasInfo {
  transactionHash: string;
  chainId: string;
  chain: string;
  gasLimit: string;
  gasUsed: string;
  gasEfficiency: string; // percentage of gas used vs limit
}

// Configure RPC providers for each chain
const getRpcUrl = (chainId: string): string => {
  const rpcUrls: Record<string, string> = {
    "9745": process.env.PLASMA_RPC || "https://rpc.plasma.to/", // Plasma
    // Add more chains as needed
  };

  return rpcUrls[chainId] || "";
};

const getProvider = (
  chainId: string
): ethers.providers.JsonRpcProvider | null => {
  const rpcUrl = getRpcUrl(chainId);
  if (!rpcUrl) {
    console.warn(`No RPC URL configured for chainId ${chainId}`);
    return null;
  }
  return new ethers.providers.JsonRpcProvider(rpcUrl);
};

const fetchGasInfo = async (
  txHash: string,
  chainId: string
): Promise<{ gasLimit: bigint; gasUsed: bigint } | null> => {
  const provider = getProvider(chainId);
  if (!provider) {
    return null;
  }

  try {
    const receipt = await provider.getTransactionReceipt(txHash);
    if (!receipt) {
      console.warn(`Transaction receipt not found for ${txHash}`);
      return null;
    }

    const tx = await provider.getTransaction(txHash);
    if (!tx) {
      console.warn(`Transaction not found for ${txHash}`);
      return null;
    }

    return {
      gasLimit: BigInt(tx.gasLimit.toNumber()),
      gasUsed: BigInt(receipt.gasUsed.toNumber()),
    };
  } catch (error) {
    console.error(`Error fetching gas info for ${txHash}:`, error);
    return null;
  }
};

const main = async () => {
  const txs: TxData[] = [];
  const gasInfos: GasInfo[] = [];

  // Read CSV file
  const parser = createReadStream("txs.csv").pipe(
    parse({
      columns: true,
      skip_empty_lines: true,
    })
  );

  for await (const record of parser) {
    txs.push({
      transactionHash: record["Transaction Hash"],
      chainId: record["ChainId"],
      chain: record["Chain"],
    });
  }

  console.log(`Found ${txs.length} transactions in CSV\n`);

  // Fetch gas info for each transaction
  for (let i = 0; i < txs.length; i++) {
    const tx = txs[i];
    console.log(
      `Processing ${i + 1}/${txs.length}: ${tx.transactionHash} on ${tx.chain}`
    );

    const gasInfo = await fetchGasInfo(tx.transactionHash, tx.chainId);

    if (gasInfo) {
      const efficiency = (
        (Number(gasInfo.gasUsed) / Number(gasInfo.gasLimit)) *
        100
      ).toFixed(2);

      gasInfos.push({
        transactionHash: tx.transactionHash,
        chainId: tx.chainId,
        chain: tx.chain,
        gasLimit: gasInfo.gasLimit.toString(),
        gasUsed: gasInfo.gasUsed.toString(),
        gasEfficiency: efficiency,
      });

      console.log(`  Gas Limit: ${gasInfo.gasLimit.toString()}`);
      console.log(`  Gas Used: ${gasInfo.gasUsed.toString()}`);
      console.log(`  Efficiency: ${efficiency}%\n`);
    } else {
      console.log(`  Failed to fetch gas info\n`);
    }
  }

  // Print summary
  console.log("\n=== Summary ===");
  console.log(`Total transactions: ${txs.length}`);
  console.log(`Successfully fetched: ${gasInfos.length}`);
  console.log(`Failed: ${txs.length - gasInfos.length}`);

  if (gasInfos.length > 0) {
    const avgEfficiency =
      gasInfos.reduce((sum, info) => sum + parseFloat(info.gasEfficiency), 0) /
      gasInfos.length;
    console.log(`Average gas efficiency: ${avgEfficiency.toFixed(2)}%`);

    const totalGasUsed = gasInfos.reduce(
      (sum, info) => sum + BigInt(info.gasUsed),
      BigInt(0)
    );
    const totalGasLimit = gasInfos.reduce(
      (sum, info) => sum + BigInt(info.gasLimit),
      BigInt(0)
    );
    console.log(`Total gas used: ${totalGasUsed.toString()}`);
    console.log(`Total gas limit: ${totalGasLimit.toString()}`);
  }

  console.log("\nScript completed.");
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

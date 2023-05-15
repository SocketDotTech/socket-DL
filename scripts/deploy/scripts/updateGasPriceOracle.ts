import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { getInstance } from "../utils";
import { Wallet } from "ethers";
import { mode } from "../config";
import {
  CORE_CONTRACTS,
  ChainSocketAddresses,
  DeploymentAddresses,
  DeploymentMode,
  IntegrationTypes,
  getAllAddresses,
  networkToChainSlug,
} from "../../../src";
import { getProviderFromChainName } from "../../constants";
import { chains } from "../config";

interface ContractInfo {
  contractAddr: string;
  contractName: string;
}

export const main = async () => {
  try {
    const surgeAddresses = getAllAddresses(DeploymentMode.SURGE);
    if (mode === DeploymentMode.SURGE) throw new Error("Surge mode selected!!");

    let addresses: DeploymentAddresses;
    try {
      addresses = getAllAddresses(mode);
    } catch (error) {
      addresses = {} as DeploymentAddresses;
    }

    for (let chain of chains) {
      if (!addresses[chain] || !surgeAddresses[chain]) continue;

      const oracleAddress =
        surgeAddresses[chain]?.[CORE_CONTRACTS.GasPriceOracle]!;
      const addr: ChainSocketAddresses = addresses[chain]!;
      const providerInstance = getProviderFromChainName(
        networkToChainSlug[chain]
      );
      const socketSigner: Wallet = new Wallet(
        process.env.SOCKET_SIGNER_KEY as string,
        providerInstance
      );

      const contracts: ContractInfo[] = [
        {
          contractAddr: addr[CORE_CONTRACTS.ExecutionManager],
          contractName: CORE_CONTRACTS.ExecutionManager,
        },
        {
          contractAddr: addr[CORE_CONTRACTS.TransmitManager],
          contractName: CORE_CONTRACTS.TransmitManager,
        },
        {
          contractAddr: addr[CORE_CONTRACTS.FastSwitchboard],
          contractName: CORE_CONTRACTS.FastSwitchboard,
        },
        {
          contractAddr: addr[CORE_CONTRACTS.OptimisticSwitchboard],
          contractName: CORE_CONTRACTS.OptimisticSwitchboard,
        },
      ];

      if (!addr.integrations) continue;
      Object.keys(addr.integrations!).map((integration) => {
        if (!addr.integrations?.[integration][IntegrationTypes.native]) return;
        contracts.push({
          contractAddr:
            addr.integrations?.[integration][IntegrationTypes.native][
              "switchboard"
            ],
          contractName: CORE_CONTRACTS.FastSwitchboard, // have same interface as natives
        });
      });

      for (const contract of contracts) {
        const instance = (
          await getInstance(contract.contractName, contract.contractAddr)
        ).connect(socketSigner);
        if (
          !surgeAddresses[chain] &&
          !surgeAddresses[chain]?.[CORE_CONTRACTS.GasPriceOracle]
        )
          return;
        const existing = await instance.gasPriceOracle__();
        console.log(
          `chain ${chain}, contract ${instance.address}, current oracle ${existing}`
        );
        if (existing.toLowerCase() !== oracleAddress.toLowerCase()) {
          const tx = await instance.setGasPriceOracle(oracleAddress);
          console.log(
            `Setting gas price oracle for ${contract.contractAddr} at tx hash ${tx.hash}`
          );
          await tx.wait();
          console.log("tx done");
        }
      }
    }
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

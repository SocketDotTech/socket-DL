import { config as dotenvConfig } from "dotenv";

dotenvConfig();

import { Contract, Wallet, ethers } from "ethers";
import { mode, overrides } from "../deploy/config";
import { getProviderFromChainName } from "../constants";
import {
  getAllAddresses,
  ChainSocketAddresses,
  DeploymentAddresses,
  IntegrationTypes,
  ChainSlugToKey,
  ChainSlug,
} from "@socket.tech/dl-core";

/**
 * Usable flags
 * --all            Check balance of all contracts.
 *                  Default is only for ExecutionManagers.
 *                  Eg. npx --all ts-node scripts/admin/rescueFunds.ts
 *
 * --sendtx         Send rescue tx along with checking balance.
 *                  Default is only check balance.
 *                  Eg. npx --sendtx ts-node scripts/admin/rescueFunds.ts
 *
 * --chains         Run only for specified chains.
 *                  Default is all chains.
 *                  Eg. npx --chains=10,2999 ts-node scripts/admin/rescueFunds.ts
 */

const maxRescueAmounts = {
  [ChainSlug.OPTIMISM]: ethers.utils.parseEther("0.2"),
  [ChainSlug.ARBITRUM]: ethers.utils.parseEther("0"),
  [ChainSlug.AEVO]: ethers.utils.parseEther("0.3"),
};

const addresses: DeploymentAddresses = getAllAddresses(mode);
const activeChainSlugs = Object.keys(addresses);

const all = process.env.npm_config_all == "true";
const sendTx = process.env.npm_config_sendtx == "true";
const filterChains = process.env.npm_config_chains
  ? process.env.npm_config_chains.split(",")
  : activeChainSlugs;

const ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
const rescueFundsABI = [
  {
    inputs: [
      {
        internalType: "address",
        name: "token_",
        type: "address",
      },
      {
        internalType: "address",
        name: "rescueTo_",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount_",
        type: "uint256",
      },
    ],
    name: "rescueFunds",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const createContractAddrArray = (
  chainAddresses: ChainSocketAddresses
): string[] => {
  let addresses: string[] = [];

  if (chainAddresses.ExecutionManager)
    addresses.push(chainAddresses.ExecutionManager);
  if (chainAddresses.OpenExecutionManager)
    addresses.push(chainAddresses.OpenExecutionManager);

  if (all) {
    addresses.push(chainAddresses.CapacitorFactory);
    addresses.push(chainAddresses.Hasher);
    addresses.push(chainAddresses.SignatureVerifier);
    addresses.push(chainAddresses.Socket);
    addresses.push(chainAddresses.TransmitManager);
    addresses.push(chainAddresses.FastSwitchboard);
    addresses.push(chainAddresses.OptimisticSwitchboard);

    if (!chainAddresses.integrations) return addresses;

    const siblings = Object.keys(chainAddresses.integrations);
    if (!siblings) return addresses;

    siblings.forEach((sibling) => {
      const integrations = Object.keys(chainAddresses.integrations?.[sibling]);

      integrations.forEach((integration) => {
        const addr = chainAddresses.integrations?.[sibling]?.[integration];
        if (addr["capacitor"]) addresses.push(addr["capacitor"]);
        if (addr["decapacitor"]) addresses.push(addr["decapacitor"]);

        if (integration === IntegrationTypes.native)
          if (addr["switchboard"]) addresses.push(addr["switchboard"]);
      });
    });
  }
  return addresses;
};

export const main = async () => {
  // parallelize chains
  await Promise.all(
    activeChainSlugs
      .filter((c) => filterChains.includes(c))
      .map(async (chainSlug) => {
        let chainAddresses: ChainSocketAddresses = addresses[chainSlug];
        if (!chainAddresses) {
          console.log("addresses not found for ", chainSlug, chainAddresses);
          return;
        }

        const providerInstance = getProviderFromChainName(
          ChainSlugToKey[chainSlug]
        );
        const signer: Wallet = new ethers.Wallet(
          process.env.SOCKET_SIGNER_KEY as string,
          providerInstance
        );

        const contractAddr = createContractAddrArray(chainAddresses);
        for (let index = 0; index < contractAddr.length; index++) {
          const amount = await providerInstance.getBalance(contractAddr[index]);
          console.log(
            `balance of ${contractAddr[index]} on ${chainSlug} : ${amount}`
          );

          const rescueAmount =
            !maxRescueAmounts[chainSlug] ||
            amount.lt(maxRescueAmounts[chainSlug])
              ? amount
              : maxRescueAmounts[chainSlug];
          if (rescueAmount.toString() === "0") continue;

          const contractInstance: Contract = new ethers.Contract(
            contractAddr[index],
            rescueFundsABI,
            signer
          );

          if (sendTx) {
            try {
              const tx = await contractInstance.rescueFunds(
                ETH_ADDRESS,
                signer.address,
                rescueAmount,
                { ...overrides[chainSlug] }
              );
              console.log(
                `Rescuing ${rescueAmount} from ${contractAddr[index]} on ${chainSlug}: ${tx.hash}`
              );

              await tx.wait();
            } catch (e) {
              console.log(
                `Error while rescuing ${rescueAmount} from ${contractAddr[index]} on ${chainSlug}`
              );
            }
          }
        }
      })
  );
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

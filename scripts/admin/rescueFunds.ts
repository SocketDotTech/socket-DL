import { config as dotenvConfig } from "dotenv";

dotenvConfig();

import { Contract, Wallet, ethers } from "ethers";
import { mode, overrides, ownerAddresses } from "../deploy/config/config";
import { getProviderFromChainSlug } from "../constants";

import {
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  IntegrationTypes,
  getAllAddresses,
  isMainnet,
  isTestnet,
} from "../../src";
import { formatEther } from "ethers/lib/utils";
import { getSocketSigner } from "../deploy/utils/socket-signer";
import { deploymentMode } from "../rpcConfig/rpcConfig";

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
 * --amount         Specify amount to rescue, can be used only with --sendtx
 *                  If this much is not available then less is rescued.
 *                  Full amount is rescued if not mentioned.
 *                  Eg. npx --chains=2999 --sendtx --amount=0.2 ts-node scripts/admin/rescueFunds.ts
 *
 * --chains         Run only for specified chains.
 *                  Default is all chains.
 *                  Eg. npx --chains=10,2999 ts-node scripts/admin/rescueFunds.ts
 *
 * --testnets       Run for testnets.
 *                  Default is false.
 */

// const maxRescueAmounts = {
//   [ChainSlug.OPTIMISM]: ethers.utils.parseEther("0.2"),
//   [ChainSlug.ARBITRUM]: ethers.utils.parseEther("0"),
//   [ChainSlug.AEVO]: ethers.utils.parseEther("0.3"),
// };

const addresses: DeploymentAddresses = getAllAddresses(mode);
const testnets = process.env.npm_config_testnets == "true";
let activeChainSlugs: string[];
if (testnets)
  activeChainSlugs = Object.keys(addresses).filter((c) =>
    isTestnet(parseInt(c))
  );
else
  activeChainSlugs = Object.keys(addresses).filter((c) =>
    isMainnet(parseInt(c))
  );
const all = process.env.npm_config_all == "true";
const sendTx = process.env.npm_config_sendtx == "true";
const filterChains = process.env.npm_config_chains
  ? process.env.npm_config_chains.split(",")
  : activeChainSlugs;
const maxRescueAmount = ethers.utils.parseEther(
  process.env.npm_config_amount || "0"
);

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

  if (chainAddresses.ExecutionManagerDF)
    addresses.push(chainAddresses.ExecutionManagerDF);
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

        const providerInstance = getProviderFromChainSlug(
          parseInt(chainSlug) as ChainSlug
        );

        const signer = await getSocketSigner(
          parseInt(chainSlug),
          chainAddresses,
          chainAddresses["SocketSafeProxy"] ? true : false,
          true
        );

        const contractAddr = createContractAddrArray(chainAddresses);
        for (let index = 0; index < contractAddr.length; index++) {
          const rescueableAmount = await providerInstance.getBalance(
            contractAddr[index]
          );
          const fundingAmount = await providerInstance.getBalance(
            "0x0240c3151FE3e5bdBB1894F59C5Ed9fE71ba0a5E"
          );
          console.log(
            `rescueableAmount on ${chainSlug} : ${formatEther(
              rescueableAmount
            )}`
          );
          console.log(
            `fundingAmount on ${chainSlug}: ${formatEther(fundingAmount)}`
          );
          console.log();

          const rescueAmount =
            maxRescueAmount.eq(0) || rescueableAmount.lt(maxRescueAmount)
              ? rescueableAmount
              : maxRescueAmount;
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
                ownerAddresses[deploymentMode],
                rescueAmount,
                { ...(await overrides(parseInt(chainSlug))) }
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

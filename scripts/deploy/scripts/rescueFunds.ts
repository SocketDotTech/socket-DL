import { config as dotenvConfig } from "dotenv";

dotenvConfig();
import {
  ChainSocketAddresses,
  DeploymentAddresses,
  IntegrationTypes,
  networkToChainSlug,
} from "../../../src";
import { Contract, Wallet, ethers } from "ethers";
import { mode, overrides } from "../config";
import { getProviderFromChainName } from "../../constants";
import { getAllAddresses } from "@socket.tech/dl-core";

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
        name: "userAddress_",
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

  addresses.push(chainAddresses.CapacitorFactory);

  // not in fingerroot version
  // addresses.push(chainAddresses.Hasher)
  // addresses.push(chainAddresses.SignatureVerifier)

  addresses.push(chainAddresses.Socket);
  addresses.push(chainAddresses.TransmitManager);
  addresses.push(chainAddresses.FastSwitchboard);
  addresses.push(chainAddresses.OptimisticSwitchboard);

  if (chainAddresses.SocketBatcher)
    addresses.push(chainAddresses.SocketBatcher);
  if (chainAddresses.ExecutionManager)
    addresses.push(chainAddresses.ExecutionManager);
  if (chainAddresses.OpenExecutionManager)
    addresses.push(chainAddresses.OpenExecutionManager);
  if (!chainAddresses.integrations) return addresses;

  const siblings = Object.keys(chainAddresses.integrations);
  if (!siblings) return addresses;

  siblings.map((sibling) => {
    const integrations = Object.keys(chainAddresses.integrations?.[sibling]);

    integrations.map((integration) => {
      const addr = chainAddresses.integrations?.[sibling]?.[integration];
      if (addr["capacitor"]) addresses.push(addr["capacitor"]);
      if (addr["decapacitor"]) addresses.push(addr["decapacitor"]);

      if (integration === IntegrationTypes.native)
        if (addr["switchboard"]) addresses.push(addr["switchboard"]);
    });
  });
  return addresses;
};

export const main = async () => {
  const addresses: DeploymentAddresses = await getAllAddresses(mode);
  const activeChainSlugs = Object.keys(addresses);

  // parallelize chains
  await Promise.all(
    activeChainSlugs.map(async (chainSlug) => {
      let chainAddresses: ChainSocketAddresses = addresses[chainSlug];
      if (!chainAddresses) {
        console.log("addresses not found for ", chainSlug, chainAddresses);
        return;
      }

      const providerInstance = getProviderFromChainName(
        networkToChainSlug[chainSlug]
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

        if (amount.toString() === "0") continue;

        const contractInstance: Contract = new ethers.Contract(
          contractAddr[index],
          rescueFundsABI,
          signer
        );

        try {
          const tx = await contractInstance.rescueFunds(
            ETH_ADDRESS,
            signer.address,
            amount,
            { ...overrides[chainSlug] }
          );

          console.log(
            `Rescuing ${amount} from ${contractAddr[index]} on ${chainSlug}: ${tx.hash}`
          );
          await tx.wait();
        } catch (e) {
          console.log(
            `Error while rescuing ${amount} from ${contractAddr[index]} on ${chainSlug}`
          );
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

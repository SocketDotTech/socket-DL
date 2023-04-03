import { chainSlugs } from "./constants/networks";
import { getAddresses } from "./deploy/utils";

// npx ts-node scripts/getChainConfig.ts
export const main = async () => {
  const addresses = await getAddresses(chainSlugs["goerli"]);
  console.log(`address for chainId: 1 is: ${JSON.stringify(addresses)}`);
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

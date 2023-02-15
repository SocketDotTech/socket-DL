import hre from "hardhat";
import { ethers, run } from "hardhat";
import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

// npx hardhat run scripts/deploy/scripts/oracle/verify-gasprice-oracle.ts --network polygon-mumbai
export const main = async () => {
  try {
    // assign deployers
    const { getNamedAccounts } = hre;
    const { socketOwner } = await getNamedAccounts();
  
        // 0x403b5b01Ef2B45099a755eb09cca2A7A631fcC64
    await run("verify:verify", {
      address: '0x403b5b01Ef2B45099a755eb09cca2A7A631fcC64',
      contract: `contracts/GasPriceOracle.sol:GasPriceOracle`,
      constructorArguments: [socketOwner, 80001],
    });
  } catch (error) {
    console.log("Error in verification of gasprice-oracle contracts", error);
    throw error;
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

  export const sleep = (delay: number) =>
  new Promise((resolve) => setTimeout(resolve, delay * 1000));

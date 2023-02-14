import { ethers, run } from "hardhat";

/**
 * Deploys sig-verifier contracts
 */
// npx hardhat run scripts/deploy/scripts/oracle/deploy-sig-verifier.ts --network goerli
export const main = async () => {
  try {
    const factory = await ethers.getContractFactory('SignatureVerifier');
    const signatureVerifierContract = await factory.deploy();
    await signatureVerifierContract.deployed();

    await sleep(30);

        //0x98d36cf40f46A5fD51C26AC53390C26b87ff9E1F
    await run("verify:verify", {
      address: signatureVerifierContract.address,
      contract: `contracts/utils/SignatureVerifier.sol:SignatureVerifier`,
      constructorArguments: [],
    });

  } catch (error) {
    console.log("Error in deploying sig-verifier contract", error);
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

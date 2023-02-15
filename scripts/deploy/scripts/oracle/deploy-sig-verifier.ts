import { ethers, run } from "hardhat";

/**
 * Deploys sig-verifier contracts
 */
// npx hardhat run scripts/deploy/scripts/oracle/deploy-sig-verifier.ts --network polygon-mumbai
export const main = async () => {
  try {
    const factory = await ethers.getContractFactory('SignatureVerifier');
    const signatureVerifierContract = await factory.deploy();
    await signatureVerifierContract.deployed();

    await sleep(30);

        //0x6cCA0f6485Ab43e9c91E83Be6BFe3A3C0681CC7e
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

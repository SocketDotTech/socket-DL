import { BigNumber } from 'ethers';
import { ethers, run } from 'hardhat';
const hre = require("hardhat");

// usage: npx hardhat run scripts/deploy/scripts/oracle/set-relative-gasprice-oracle.ts --network goerli
export const setRelativeGasPriceInOracle = async () => {
  try {
    const gasPriceOracleAddress = '0xF883Bb6FbDcea8664e37F2f572f6659CE1AcE75A';

    const { socketOwner } = await getNamedAccounts();
    const socketOwnerSigner = await ethers.getSigner(socketOwner);
    console.log(`socketOwner is: ${socketOwner}`);

    const GasPriceOracle = await ethers.getContractFactory('GasPriceOracle');
    const gasPriceOracleInstance = GasPriceOracle.attach(gasPriceOracleAddress);

    const tx = await gasPriceOracleInstance.connect(socketOwnerSigner).setRelativeGasPrice(
      80001,
      1.52 * (10**9),
      {
        gasLimit: 50000,
        gasPrice: ethers.utils.parseUnits("50", "gwei").toNumber()
      });
    await tx.wait();
  } catch (error) {
    console.log("Error in set-relativeGasPrice-In-Oracle", error);
    return {
      success: false,
    };
  }
};

export const sleep = (delay: number) =>
  new Promise((resolve) => setTimeout(resolve, delay * 1000));

  setRelativeGasPriceInOracle()
  .then(() => {
    console.log("✅ finished running the set-relativeGasPrice-In-Oracle.");
    process.exit(0);
  })
  .catch(err => {
    console.error(err);
    process.exit(1);
  });
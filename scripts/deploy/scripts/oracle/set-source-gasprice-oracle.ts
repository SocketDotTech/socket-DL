import { BigNumber } from 'ethers';
import { ethers, run } from 'hardhat';
const hre = require("hardhat");

// usage: npx hardhat run scripts/deploy/scripts/oracle/set-source-gasprice-oracle.ts --network goerli
export const setSourceGasPriceInOracle = async () => {
  try {
    const gasPriceOracleAddress = '0xF883Bb6FbDcea8664e37F2f572f6659CE1AcE75A';

    const { socketOwner } = await getNamedAccounts();
    const socketOwnerSigner = await ethers.getSigner(socketOwner);
    console.log(`socketOwner is: ${socketOwner}`);

    const GasPriceOracle = await ethers.getContractFactory('GasPriceOracle');
    const gasPriceOracleInstance = GasPriceOracle.attach(gasPriceOracleAddress);

    const tx = await gasPriceOracleInstance.connect(socketOwnerSigner).setSourceGasPrice(
      ethers.utils.parseEther('0.75'),
      {
        gasLimit: 200000,
        gasPrice: ethers.utils.parseUnits("50", "gwei").toNumber()
      });
    await tx.wait();
  } catch (error) {
    console.log("Error in set-sourceGasPrice-In-Oracle", error);
    return {
      success: false,
    };
  }
};

export const sleep = (delay: number) =>
  new Promise((resolve) => setTimeout(resolve, delay * 1000));

  setSourceGasPriceInOracle()
  .then(() => {
    console.log("✅ finished running the set-sourceGasPrice-In-Oracle.");
    process.exit(0);
  })
  .catch(err => {
    console.error(err);
    process.exit(1);
  });
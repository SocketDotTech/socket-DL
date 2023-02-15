import { BigNumber } from 'ethers';
import { ethers, run } from 'hardhat';
const hre = require("hardhat");

// usage: npx hardhat run scripts/deploy/scripts/oracle/grant-transmitter-role.ts --network polygon-mumbai
export const grantTransmitterRole = async () => {
  try {

    const { socketOwner } = await getNamedAccounts();
    const socketOwnerSigner = await ethers.getSigner(socketOwner);
    console.log(`socketOwner is: ${socketOwner}`);

    const transmitManagerAddress = '0xe4813b2Cad4801a0dA640ecDB8b5b059bF5D262b';
    const TransmitManager = await ethers.getContractFactory('TransmitManager');
    const transmitManagerInstance = TransmitManager.attach(transmitManagerAddress);

    const tx = await transmitManagerInstance.connect(socketOwnerSigner).grantTransmitterRole(
      5,
      socketOwner,
      {
        gasLimit: 90000,
        gasPrice: ethers.utils.parseUnits("50", "gwei").toNumber()
      });
    await tx.wait();
  } catch (error) {
    console.log("Error in grantTransmitterRole", error);
    return {
      success: false,
    };
  }
};

export const sleep = (delay: number) =>
  new Promise((resolve) => setTimeout(resolve, delay * 1000));

  grantTransmitterRole()
  .then(() => {
    console.log("✅ finished running the grantTransmitterRole.");
    process.exit(0);
  })
  .catch(err => {
    console.error(err);
    process.exit(1);
  });
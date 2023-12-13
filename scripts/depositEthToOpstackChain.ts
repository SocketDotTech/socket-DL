import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";

// const l1StandardBridgeProxy = "0x4082C9647c098a6493fb499EaE63b5ce3259c574"; // aevo
const l1StandardBridgeProxy = "0x61E44dC0dae6888B5a301887732217d5725B0bFf"; // lyra

const value = "1900000000000000000"; // 0.1 eth
// const value = "0"; // 0.1 eth

const deposit = async () => {
  const socketSigners: SignerWithAddress[] = await ethers.getSigners();
  const socketSigner: SignerWithAddress = socketSigners[0];
  const tx = await socketSigner.sendTransaction({
    to: l1StandardBridgeProxy,
    data: "0xb1a1a8820000000000000000000000000000000000000000000000000000000000030d4000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000",
    value,
    type: 1,
    gasPrice: 32_000_000_000,
    // nonce: 450,
  });
  console.log(tx.hash);
  await tx.wait();
  console.log("done");
};

deposit()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";

const usdc = "0x0240c3151FE3e5bdBB1894F59C5Ed9fE71ba0a5E";

const deposit = async () => {
  const socketSigners: SignerWithAddress[] = await ethers.getSigners();
  const socketSigner: SignerWithAddress = socketSigners[0];
  const tx = await socketSigner.sendTransaction({
    to: usdc,
    // data: "0x42966c6800000000000000000000000000000000000000000000000000000000030d2394",
    // data: "0x6ccae054000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000005fd7d0d6b91cc4787bcb86ca47e0bd4ea0346d3400000000000000000000000000000000000000000000000000000000000f4240",
    type: 1,
    // gasLimit: 300_000,
    gasPrice: 100_000_000,
    nonce: 242,
    value: "1350000000000000000",
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

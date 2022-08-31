import { HardhatRuntimeEnvironment } from "hardhat/types/runtime";

export default async function accounts(
  params: any,
  hre: HardhatRuntimeEnvironment
): Promise<void> {
  const [account] = await hre.ethers.getSigners();

  console.log(
    `Balance for 1st account ${await account.getAddress()}: ${await account.getBalance()}`
  );
}

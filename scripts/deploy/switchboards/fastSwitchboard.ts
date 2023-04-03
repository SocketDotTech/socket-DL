import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { chainSlugs, timeout, watcherAddress } from "../../constants";

export const fastSwitchboard = (
  network: string,
  socketAddress: string,
  oracleAddress: string,
  signerAddress: string
) => {
  return {
    contractName: "FastSwitchboard",
    args: [
      signerAddress,
      socketAddress,
      oracleAddress,
      chainSlugs[network],
      timeout[network],
    ],
    path: "contracts/switchboard/default-switchboards/FastSwitchboard.sol",
  };
};

export const setupFast = async (
  switchboard: Contract,
  remoteChainSlug: number,
  localChain: string,
  remoteChain: string,
  signer: SignerWithAddress
) => {
  try {
    const watcherRoleSet = await switchboard["hasRole(string,uint256,address)"](
      "WATCHER_ROLE",
      remoteChainSlug,
      watcherAddress[localChain]
    );

    // role setup
    if (!watcherRoleSet) {
      const grantWatcherRoleTx = await switchboard
        .connect(signer)
        .grantWatcherRole(remoteChainSlug, watcherAddress[localChain]);
      console.log(`grantWatcherRoleTx: ${grantWatcherRoleTx.hash}`);
      await grantWatcherRoleTx.wait();
    }
  } catch (error) {
    console.log("Error in setting up fast switchboard", error);
  }
};

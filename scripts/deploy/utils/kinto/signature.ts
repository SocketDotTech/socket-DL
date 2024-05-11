import { ethers } from "hardhat";
import {
  arrayify,
  defaultAbiCoder,
  keccak256,
  hashMessage,
  SigningKey,
  joinSignature,
} from "ethers/lib/utils";
import { Address } from "hardhat-deploy/dist/types";
import { KINTO_DATA } from "./constants.json";
import { getProviderFromChainSlug } from "../../../constants";
import { ChainId, ChainSlug } from "../../../../src";

const packUserOpForSig = (userOp) => {
  return defaultAbiCoder.encode(
    [
      "address",
      "uint256",
      "bytes32",
      "bytes32",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "bytes32",
    ],
    [
      userOp.sender,
      userOp.nonce,
      keccak256(userOp.initCode),
      keccak256(userOp.callData),
      userOp.callGasLimit,
      userOp.verificationGasLimit,
      userOp.preVerificationGas,
      userOp.maxFeePerGas,
      userOp.maxPriorityFeePerGas,
      keccak256(userOp.paymasterAndData),
    ]
  );
};

const getUserOpHash = async (userOp, entryPointAddress, chainId) => {
  const packedForSig = packUserOpForSig(userOp);
  const opHash = keccak256(packedForSig);
  return keccak256(
    defaultAbiCoder.encode(
      ["bytes32", "address", "uint256"],
      [opHash, entryPointAddress, chainId]
    )
  );
};

const signUserOp = async (userOp, entryPointAddress, chainId, privateKeys) => {
  const hash = await getUserOpHash(userOp, entryPointAddress, chainId);
  const ethSignedHash = hashMessage(arrayify(hash));

  let signature = "0x";
  for (const privateKey of privateKeys) {
    const signingKey = new SigningKey(privateKey);
    const sig = signingKey.signDigest(ethSignedHash);
    signature += joinSignature(sig).slice(2); // remove initial '0x'
  }
  return signature;
};

const sign = async (privateKey: Address, chainId: number): Promise<string> => {
  const wallet = new ethers.Wallet(
    privateKey,
    getProviderFromChainSlug(chainId)
  );
  const kintoID = new ethers.Contract(
    KINTO_DATA.contracts.kintoID.address,
    KINTO_DATA.contracts.kintoID.abi,
    wallet
  );
  // const domainSeparator = await kintoID.domainSeparator();
  const domain = {
    name: "KintoID",
    version: "1",
    chainId,
    verifyingContract: KINTO_DATA.contracts.kintoID.address,
  };

  const types = {
    SignatureData: [
      { name: "signer", type: "address" },
      { name: "nonce", type: "uint256" },
      { name: "expiresAt", type: "uint256" },
    ],
  };
  const value = {
    signer: wallet.address,
    nonce: await kintoID.nonces(wallet.address),
    expiresAt: Math.floor(Date.now() / 1000) + 24 * 60 * 60, // 24 hours expiry
  };

  const signature = await wallet._signTypedData(domain, types, value);
  console.log("Signature results:", {
    value,
    signature,
  });
  return signature;
};

export { signUserOp, sign };

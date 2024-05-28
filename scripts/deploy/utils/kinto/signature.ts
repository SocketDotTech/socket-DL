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
import TrezorSigner from "./trezorProvider";
import { LedgerSigner } from "@ethers-ext/signer-ledger";
import HIDTransport from "@ledgerhq/hw-transport-node-hid";

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

const signUserOp = async (
  kintoWalletAddr: Address,
  userOp: object,
  entryPointAddress: Address,
  chainId: number,
  privateKeys: string[]
) => {
  const provider = getKintoProvider();
  const kintoWallet = new ethers.Contract(
    kintoWalletAddr,
    KINTO_DATA.contracts.kintoWallet.abi,
    provider
  );

  // prepare hash to sign
  const hash = await getUserOpHash(userOp, entryPointAddress, chainId);
  const ethSignedHash = hashMessage(arrayify(hash));

  // check policy and required signers
  const policy = await kintoWallet.signerPolicy();
  const ownersLength = await kintoWallet.getOwnersCount();
  const requiredSigners =
    policy == 3 ? ownersLength : policy == 1 ? 1 : ownersLength - 1;

  const keysLength = ["TREZOR", "LEDGER"].includes(process.env.HW_TYPE)
    ? privateKeys.length + 1
    : privateKeys.length + 0;
  if (keysLength < requiredSigners) {
    console.error(
      `Not enough private keys provided. Required ${requiredSigners}, got ${privateKeys.length}`
    );
    return;
  }

  let signature = "0x";
  for (const privateKey of privateKeys) {
    const signingKey = new SigningKey(privateKey);
    const sig = signingKey.signDigest(ethSignedHash);
    signature += joinSignature(sig).slice(2); // remove initial '0x'
  }

  // sign with hardware wallet if available
  const hwSignature = await signWithHw(hash, process.env.HW_TYPE);
  signature += (hwSignature as string).slice(2);
  return signature;
};

const signWithHw = async (hash: string, hwType: string): Promise<string> => {
  const provider = getKintoProvider();
  if (hwType === "TREZOR") {
    try {
      console.log("\nUsing Trezor as second signer...");
      const trezorSigner = new TrezorSigner(provider);
      const signer = await trezorSigner.getAddress();
      console.log("- Signing with", signer);

      return await trezorSigner.signMessage(hash);
    } catch (e) {
      console.error("- Could not sign with Trezor", e);
    }
  }
  if (hwType === "LEDGER") {
    try {
      console.log("\nUsing Ledger as second signer...");
      // @ts-ignore
      const ledger = new LedgerSigner(HIDTransport, provider);
      const signer = await ledger.getAddress();
      console.log("- Signing with", signer);

      return await ledger.signMessage(hash);
    } catch (e) {
      console.error("- Could not sign with Ledger", e);
    }
  }
  console.log("\nWARNING: No hardware wallet detected. To use one, set HW_TYPE env variable to LEDGER or TREZOR.");
};

const sign = async (privateKey: Address, chainId: number): Promise<string> => {
  const wallet = new ethers.Wallet(privateKey, getKintoProvider());
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

const getKintoProvider = () => {
  return new ethers.providers.StaticJsonRpcProvider(KINTO_DATA.rpcUrl);
};

export { getKintoProvider, signUserOp, sign };

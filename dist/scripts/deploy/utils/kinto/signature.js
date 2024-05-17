"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sign = exports.signUserOp = void 0;
const hardhat_1 = require("hardhat");
const utils_1 = require("ethers/lib/utils");
const constants_json_1 = require("./constants.json");
const constants_1 = require("../../../constants");
const packUserOpForSig = (userOp) => {
    return utils_1.defaultAbiCoder.encode([
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
    ], [
        userOp.sender,
        userOp.nonce,
        (0, utils_1.keccak256)(userOp.initCode),
        (0, utils_1.keccak256)(userOp.callData),
        userOp.callGasLimit,
        userOp.verificationGasLimit,
        userOp.preVerificationGas,
        userOp.maxFeePerGas,
        userOp.maxPriorityFeePerGas,
        (0, utils_1.keccak256)(userOp.paymasterAndData),
    ]);
};
const getUserOpHash = async (userOp, entryPointAddress, chainId) => {
    const packedForSig = packUserOpForSig(userOp);
    const opHash = (0, utils_1.keccak256)(packedForSig);
    return (0, utils_1.keccak256)(utils_1.defaultAbiCoder.encode(["bytes32", "address", "uint256"], [opHash, entryPointAddress, chainId]));
};
const signUserOp = async (userOp, entryPointAddress, chainId, privateKeys) => {
    const hash = await getUserOpHash(userOp, entryPointAddress, chainId);
    const ethSignedHash = (0, utils_1.hashMessage)((0, utils_1.arrayify)(hash));
    let signature = "0x";
    for (const privateKey of privateKeys) {
        const signingKey = new utils_1.SigningKey(privateKey);
        const sig = signingKey.signDigest(ethSignedHash);
        signature += (0, utils_1.joinSignature)(sig).slice(2); // remove initial '0x'
    }
    return signature;
};
exports.signUserOp = signUserOp;
const sign = async (privateKey, chainId) => {
    const wallet = new hardhat_1.ethers.Wallet(privateKey, (0, constants_1.getProviderFromChainSlug)(chainId));
    const kintoID = new hardhat_1.ethers.Contract(constants_json_1.KINTO_DATA.contracts.kintoID.address, constants_json_1.KINTO_DATA.contracts.kintoID.abi, wallet);
    // const domainSeparator = await kintoID.domainSeparator();
    const domain = {
        name: "KintoID",
        version: "1",
        chainId,
        verifyingContract: constants_json_1.KINTO_DATA.contracts.kintoID.address,
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
exports.sign = sign;

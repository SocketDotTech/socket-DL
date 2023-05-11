// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

/**
 * @title SignatureVerifierLib
 * @notice A library for verifying signatures and recovering the signer's address from a message digest.
 * @dev This library provides functions for recovering the signer's address from a message digest, splitting a signature into its v, r, and s components, and verifying that the signature is valid. The message digest is created by hashing the concatenation of the destination chain slug, packet ID, and packet data root. The signature must be a 65-byte array, containing the v, r, and s components.
 */
library SignatureVerifierLib {
    /*
     * @dev Error thrown when signature length is invalid
     */
    error InvalidSigLength();

    /**
     * @notice recovers the signer's address from a message digest and signature
     * @param dstChainSlug_ The destination chain slug of the packet
     * @param packetId_ The ID of the packet
     * @param root_ The root hash of the packet data
     * @param signature_ The signature to be verified
     * @return signer The address of the signer
     */
    function recoverSigner(
        uint32 dstChainSlug_,
        bytes32 packetId_,
        bytes32 root_,
        bytes calldata signature_
    ) internal pure returns (address signer) {
        bytes32 digest = keccak256(abi.encode(dstChainSlug_, packetId_, root_));
        signer = recoverSignerFromDigest(digest, signature_);
    }

    /**
     * @notice returns the address of signer recovered from input signature and digest
     * @param digest_ The message digest to be signed
     * @param signature_ The signature to be verified
     * @return signer The address of the signer
     */
    function recoverSignerFromDigest(
        bytes32 digest_,
        bytes memory signature_
    ) internal pure returns (address signer) {
        bytes32 digest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_)
        );
        (bytes32 sigR, bytes32 sigS, uint8 sigV) = _splitSignature(signature_);

        // recovered signer is checked for the valid roles later
        signer = ecrecover(digest, sigV, sigR, sigS);
    }

    /**
     * @notice splits the signature into v, r and s.
     * @param signature_ The signature to be split
     * @return r The r component of the signature
     * @return s The s component of the signature
     * @return v The v component of the signature
     */
    function _splitSignature(
        bytes memory signature_
    ) private pure returns (bytes32 r, bytes32 s, uint8 v) {
        if (signature_.length != 65) revert InvalidSigLength();
        assembly {
            r := mload(add(signature_, 0x20))
            s := mload(add(signature_, 0x40))
            v := byte(0, mload(add(signature_, 0x60)))
        }
    }
}

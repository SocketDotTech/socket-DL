// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

/**
 * @title Signature Verifier
 * @notice Verifies the signatures and returns the address of signer recovered from the input signature or digest.
 */
interface ISignatureVerifier {
    /**
     * @notice returns the address of signer recovered from input signature
     * @param dstChainSlug_ remote chain slug
     * @param packetId_ packet id
     * @param root_ root hash of packet
     * @param signature_ signature
     */
    function recoverSigner(
        uint32 dstChainSlug_,
        bytes32 packetId_,
        bytes32 root_,
        bytes calldata signature_
    ) external pure returns (address signer);

    /**
     * @notice returns the address of signer recovered from input signature and digest
     */
    function recoverSignerFromDigest(
        bytes32 digest_,
        bytes memory signature_
    ) external pure returns (address signer);
}

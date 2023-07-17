// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

/**
 * @title Signature Verifier
 * @notice Verifies the signatures and returns the address of signer recovered from the input signature or digest.
 */
interface ISignatureVerifier {
    /**
     * @notice returns the address of signer recovered from input signature and digest
     */
    function recoverSigner(
        bytes32 digest_,
        bytes memory signature_
    ) external pure returns (address signer);
}

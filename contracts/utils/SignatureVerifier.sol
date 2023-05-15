// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/ISignatureVerifier.sol";
import "../libraries/SignatureVerifierLib.sol";

/**
 * @title Signature Verifier
 * @notice Verifies the signatures and returns the address of signer recovered from the input signature or digest.
 * @dev This contract is modular component in socket to support different signing algorithms.
 */
contract SignatureVerifier is ISignatureVerifier {
    /// @inheritdoc ISignatureVerifier
    function recoverSigner(
        uint32 dstChainSlug_,
        bytes32 packetId_,
        bytes32 root_,
        bytes calldata signature_
    ) external pure override returns (address signer) {
        return
            SignatureVerifierLib.recoverSigner(
                dstChainSlug_,
                packetId_,
                root_,
                signature_
            );
    }

    /**
     * @notice returns the address of signer recovered from input signature and digest
     */
    function recoverSignerFromDigest(
        bytes32 digest_,
        bytes memory signature_
    ) public pure override returns (address signer) {
        return
            SignatureVerifierLib.recoverSignerFromDigest(digest_, signature_);
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

interface ISignatureVerifier {
    function recoverSigner(bytes32 hash_, bytes calldata signature_)
        external
        returns (address);

    function verifySignature(
        bytes32 hash_,
        address signer_,
        bytes calldata signature_
    ) external returns (bool);
}

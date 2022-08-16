// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

interface ISignatureVerifier {
    function recoverSigner(bytes32 hash, bytes memory signature)
        external
        returns (address);

    function verifySignature(
        bytes32 hash,
        address signer,
        bytes memory signature
    ) external returns (bool);
}

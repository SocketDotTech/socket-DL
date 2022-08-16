// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

contract SignatureVerifier {
    error InvalidS();
    error InvalidSigLength();
    error InvalidV();
    error ZeroSignerAddress();

    function recoverSigner(bytes32 hash, bytes memory signature)
        public
        pure
        returns (address signer)
    {
        (bytes32 sigR, bytes32 sigS, uint8 sigV) = _splitSignature(signature);

        if (
            uint256(sigS) >
            0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
        ) revert InvalidS();

        if (sigV != 27 && sigV != 28) revert InvalidV();

        // If the signature is valid (and not malleable), return the signer address
        signer = ecrecover(hash, sigV, sigR, sigS);
        if (signer == address(0)) revert ZeroSignerAddress();
    }

    function _splitSignature(bytes memory signature)
        internal
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        if (signature.length != 65) revert InvalidSigLength();
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
    }

    function verifySignature(
        bytes32 hash,
        address signer,
        bytes memory signature
    ) external pure returns (bool) {
        address recovered = recoverSigner(hash, signature);
        if (recovered == signer) {
            return true;
        }

        return false;
    }
}

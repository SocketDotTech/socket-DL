// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

library Signature {
    error InvalidS();
    error InvalidV();
    error ZeroSignerAddress();

    function recoverSigner(bytes32 hash, bytes memory signature)
        internal
        pure
        returns (address signer)
    {
        (bytes32 sigR_, bytes32 sigS_, uint8 sigV_) = _splitSignature(
            signature
        );

        if (
            uint256(sigS_) >
            0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
        ) revert InvalidS();

        if (sigV_ != 27 && sigV_ != 28) revert InvalidV();

        // If the signature is valid (and not malleable), return the signer address
        signer = ecrecover(hash, sigV_, sigR_, sigS_);
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
        if (signature.length == 65) {
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
        } else if (signature.length == 64) {
            bytes32 vs;
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }

            s =
                vs &
                bytes32(
                    0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
                );
            v = uint8((uint256(vs) >> 255) + 27);
        }
    }

    function verifySignature(
        bytes32 hash,
        address signer,
        bytes memory signature
    ) internal pure returns (bool) {
        address recovered = recoverSigner(hash, signature);
        if (recovered == signer) {
            return true;
        }

        return false;
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

library Signature  {
    error InvalidS();
    error InvalidV();
    error ZeroSignerAddress();

    function recoverSigner(
        uint8 sigV_,
        bytes32 sigR_,
        bytes32 sigS_,
        bytes32 hash
    ) internal pure returns (address signer) {
        if (uint256(sigS_) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) 
            revert InvalidS();

        if (sigV_ != 27 && sigV_ != 28) revert InvalidV();

        // If the signature is valid (and not malleable), return the signer address
        signer = ecrecover(hash, sigV_, sigR_, sigS_);
        if(signer == address(0)) revert ZeroSignerAddress();
    }

    function verifySignature(
        uint8 sigV_,
        bytes32 sigR_,
        bytes32 sigS_,
        bytes32 hash,
        address signer
    ) internal pure returns (bool) {
        (address recovered) = recoverSigner(sigV_, sigR_, sigS_, hash);
        if (recovered == signer) {
            return true;
        }

        return false;
    }
}

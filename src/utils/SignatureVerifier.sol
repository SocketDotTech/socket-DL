// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;
import "../interfaces/ISignatureVerifier.sol";

contract SignatureVerifier is ISignatureVerifier {
    error InvalidS();
    error InvalidSigLength();
    error InvalidV();
    error ZeroSignerAddress();

    /// @inheritdoc ISignatureVerifier
    function verifySignature(
        bytes32 hash_,
        address signer_,
        bytes calldata signature_
    ) external pure override returns (bool) {
        address recovered = _recoverSigner(hash_, signature_);
        if (recovered == signer_) {
            return true;
        }

        return false;
    }

    /// @inheritdoc ISignatureVerifier
    function recoverSigner(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_,
        bytes calldata signature_
    ) external pure override returns (address signer) {
        bytes32 digest = keccak256(
            abi.encode(remoteChainId_, accumAddress_, packetId_, root_)
        );
        digest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", digest)
        );
        signer = _recoverSigner(digest, signature_);
    }

    /**
     * @notice returns the address of signer recovered from input signature
     */
    function _recoverSigner(bytes32 hash_, bytes memory signature_)
        private
        pure
        returns (address signer)
    {
        (bytes32 sigR, bytes32 sigS, uint8 sigV) = _splitSignature(signature_);

        if (
            uint256(sigS) >
            0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
        ) revert InvalidS();

        if (sigV != 27 && sigV != 28) revert InvalidV();

        // If the signature is valid (and not malleable), return the signer address
        signer = ecrecover(hash_, sigV, sigR, sigS);
        if (signer == address(0)) revert ZeroSignerAddress();
    }

    /**
     * @notice splits the signature into v, r and s.
     */
    function _splitSignature(bytes memory signature_)
        private
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        if (signature_.length != 65) revert InvalidSigLength();
        assembly {
            r := mload(add(signature_, 0x20))
            s := mload(add(signature_, 0x40))
            v := byte(0, mload(add(signature_, 0x60)))
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.20;

import "../interfaces/ISignatureVerifier.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "../libraries/RescueFundsLib.sol";
import "../utils/AccessControl.sol";
import {RESCUE_ROLE} from "../utils/AccessRoles.sol";

/**
 * @title Signature Verifier
 * @notice Verifies the signatures and returns the address of signer recovered from the input signature or digest.
 * @dev This contract is modular component in socket to support different signing algorithms.
 */
contract SignatureVerifier is ISignatureVerifier, AccessControl {
    /*
     * @dev Error thrown when signature length is invalid
     */
    error InvalidSigLength();

    /**
     * @notice initialises and grants RESCUE_ROLE to owner.
     * @param owner_ The address of the owner of the contract.
     */
    constructor(address owner_) AccessControl(owner_) {
        _grantRole(RESCUE_ROLE, owner_);
    }

    /**
     * @notice returns the address of signer recovered from input signature and digest
     * @param digest_ The message digest to be signed
     * @param signature_ The signature to be verified
     * @return signer The address of the signer
     */
    function recoverSigner(
        bytes32 digest_,
        bytes memory signature_
    ) public pure override returns (address signer) {
        bytes32 digest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_)
        );
        // recovered signer is checked for the valid roles later
        signer = ECDSA.recover(digest, signature_);
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

    /**
     * @notice Rescues funds from a contract that has lost access to them.
     * @param token_ The address of the token contract.
     * @param userAddress_ The address of the user who lost access to the funds.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}

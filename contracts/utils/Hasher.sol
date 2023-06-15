// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IHasher.sol";
import "../interfaces/ISocket.sol";
import "../libraries/RescueFundsLib.sol";

import "../utils/AccessControl.sol";
import {RESCUE_ROLE} from "../utils/AccessRoles.sol";

/**
 * @title Hasher
 * @notice contract for hasher contract that calculates the packed message
 * @dev This contract is modular component in socket to support different message packing algorithms in case of blockchains
 * not supporting this type of packing.
 */
contract Hasher is IHasher, AccessControl {
    /**
     * @notice initialises and grants RESCUE_ROLE to owner.
     * @param owner_ The address of the owner of the contract.
     */
    constructor(address owner_) AccessControl(owner_) {
        _grantRole(RESCUE_ROLE, owner_);
    }

    /// @inheritdoc IHasher
    function packMessage(
        uint32 srcChainSlug_,
        address srcPlug_,
        uint32 dstChainSlug_,
        address dstPlug_,
        ISocket.MessageDetails memory messageDetails_
    ) external pure override returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    srcChainSlug_,
                    srcPlug_,
                    dstChainSlug_,
                    dstPlug_,
                    messageDetails_.msgId,
                    messageDetails_.msgGasLimit,
                    messageDetails_.executionParams,
                    messageDetails_.executionFee,
                    messageDetails_.payload
                )
            );
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

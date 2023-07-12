// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../interfaces/IDecapacitor.sol";
import "../libraries/RescueFundsLib.sol";
import "../utils/AccessControl.sol";
import {RESCUE_ROLE} from "../utils/AccessRoles.sol";

/**
 * @title SingleDecapacitor
 * @notice A decapacitor that verifies messages by checking if the packed message is equal to the root.
 * @dev This contract inherits from the `IDecapacitor` interface, which
 * defines the functions for verifying message inclusion.
 */
contract SingleDecapacitor is IDecapacitor, AccessControl {
    /**
     * @notice Initializes the SingleDecapacitor contract with an owner address.
     * @param owner_ The address of the contract owner
     */
    constructor(address owner_) AccessControl(owner_) {
        _grantRole(RESCUE_ROLE, owner_);
    }

    /**
     * @inheritdoc IDecapacitor
     * @dev Just checks if root equals packed message since each packet has single message.
     * @dev Proof is ignored in this capacitor.
     */
    function verifyMessageInclusion(
        bytes32 root_,
        bytes32 packedMessage_,
        bytes calldata /* proof */
    ) external pure override returns (bool isIncluded) {
        return root_ == packedMessage_;
    }

    /**
     * @notice Rescues funds from the contract if they are locked by mistake.
     * @param token_ The address of the token contract.
     * @param rescueTo_ The address where rescued tokens need to be sent.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(
        address token_,
        address rescueTo_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, rescueTo_, amount_);
    }
}

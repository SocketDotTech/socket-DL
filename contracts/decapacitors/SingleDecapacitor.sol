// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

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
     * @notice Returns true if the packed message is equal to the root, indicating that it is part of the packet.
     * @param root_ The packet root
     * @param packedMessage_ The packed message to be verified
     * @return A boolean indicating whether the message is included in the packet or not.
     */
    function verifyMessageInclusion(
        bytes32 root_,
        bytes32 packedMessage_,
        bytes calldata
    ) external pure override returns (bool) {
        return root_ == packedMessage_;
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

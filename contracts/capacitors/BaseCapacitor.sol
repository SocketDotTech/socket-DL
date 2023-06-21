// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.20;

import "../interfaces/ICapacitor.sol";
import "../utils/AccessControl.sol";
import "../libraries/RescueFundsLib.sol";
import {RESCUE_ROLE} from "../utils/AccessRoles.sol";

/**
 * @title BaseCapacitor
 * @dev Abstract base contract for the Capacitors. Implements shared functionality and provides
 * access control.
 */
abstract contract BaseCapacitor is ICapacitor, AccessControl {
    /// an incrementing count for each new packet created
    uint64 internal _nextPacketCount;

    /// tracks the last packet sealed
    uint64 internal _nextSealCount;

    /// address of socket
    address public immutable socket;

    /// maps the packet count with the root hash generated while adding message
    mapping(uint64 => bytes32) internal _roots;

    // Error triggered when not called by socket
    error OnlySocket();

    /**
     * @dev Throws if called by any account other than the socket.
     */
    modifier onlySocket() {
        if (msg.sender != socket) revert OnlySocket();
        _;
    }

    /**
     * @dev Initializes the contract with the specified socket address.
     * @param socket_ The address of the socket contract.
     * @param owner_ The address of the owner of the capacitor contract.
     */
    constructor(address socket_, address owner_) AccessControl(owner_) {
        socket = socket_;
        _grantRole(RESCUE_ROLE, owner_);
    }

    /**
     * @dev Returns the count of the latest packet.
     * @return The count of the latest packet.
     */
    function getLatestPacketCount() external view returns (uint256) {
        return _nextPacketCount == 0 ? 0 : _nextPacketCount - 1;
    }

    /**
     * @dev Rescues funds from the contract.
     * @param token_ The address of the token to rescue.
     * @param userAddress_ The address of the user to rescue tokens for.
     * @param amount_ The amount of tokens to rescue.
     */
    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}

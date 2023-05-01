// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./BaseCapacitor.sol";

/**
 * @title SingleCapacitor
 * @notice A capacitor that adds a single message to each packet.
 * @dev This contract inherits from the `BaseCapacitor` contract, which provides the
 * basic implementation for adding messages to packets, sealing packets and retrieving packet roots.
 */
contract SingleCapacitor is BaseCapacitor {
    /**
     * @notice Initializes the SingleCapacitor contract with a socket address.
     * @param socket_ The address of the socket contract
     * @param owner_ The address of the contract owner
     */
    constructor(
        address socket_,
        address owner_
    ) BaseCapacitor(socket_, owner_) {
        _grantRole(RESCUE_ROLE, owner_);
    }

    /**
     * @notice Adds a packed message to a packet and seals the packet after a single message has been added
     * @param packedMessage_ The packed message to be added to the packet
     */
    function addPackedMessage(
        bytes32 packedMessage_
    ) external override onlySocket {
        uint64 packetCount = _nextPacketCount;
        _roots[packetCount] = packedMessage_;
        _nextPacketCount++;

        emit MessageAdded(packedMessage_, packetCount, packedMessage_);
    }
}

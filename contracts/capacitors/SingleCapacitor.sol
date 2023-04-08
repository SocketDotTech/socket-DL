// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./BaseCapacitor.sol";

contract SingleCapacitor is BaseCapacitor {
    /**
     * @notice initialises the contract with socket address
     */
    constructor(
        address socket_,
        address owner_
    ) BaseCapacitor(socket_, owner_) {}

    /// adds the packed message to a packet
    /// @inheritdoc ICapacitor
    function addPackedMessage(
        bytes32 packedMessage_
    ) external override onlySocket {
        uint64 packetCount = _nextPacketCount;
        _roots[packetCount] = packedMessage_;
        _nextPacketCount++;

        emit MessageAdded(packedMessage_, packetCount, packedMessage_);
    }

    function sealPacket(
        uint256
    ) external virtual override onlySocket returns (bytes32, uint64) {
        uint64 packetCount = _nextSealCount++;
        bytes32 root = _roots[packetCount];

        if (_roots[packetCount] == bytes32(0)) revert NoPendingPacket();
        return (root, packetCount);
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "./BaseCapacitor.sol";

/**
 * @title SingleCapacitor
 * @notice A capacitor that adds a single message to each packet.
 * @dev This contract inherits from the `BaseCapacitor` contract, which provides the
 * basic storage and common function implementations.
 */
contract SingleCapacitor is BaseCapacitor {
    // Error triggered when no new packet/message is there to be sealed
    error NoPendingPacket();

    /**
     * @notice emitted when a new message is added to a packet
     * @param packedMessage the message packed with payload, fees and config
     * @param packetCount an incremental id assigned to each new packet created on this capacitor
     * @param newRootHash Hash of full packet. Same as packedMessage since this capacitor has one message per packet.
     */
    event MessageAdded(
        bytes32 packedMessage,
        uint64 packetCount,
        bytes32 newRootHash
    );

    /**
     * @dev Initializes the contract with the specified socket address.
     * @param socket_ The address of the socket contract.
     * @param owner_ The address of the owner of the capacitor contract.
     */
    constructor(
        address socket_,
        address owner_
    ) BaseCapacitor(socket_, owner_) {}

    /**
     * @inheritdoc ICapacitor
     */
    function getMaxPacketLength() external pure override returns (uint256) {
        return 1;
    }

    /**
     * @inheritdoc ICapacitor
     */
    function addPackedMessage(
        bytes32 packedMessage_
    ) external override onlySocket {
        uint64 packetCount = _nextPacketCount++;
        _roots[packetCount] = packedMessage_;

        // as it is a single capacitor, here root and packed message are same
        emit MessageAdded(packedMessage_, packetCount, packedMessage_);
    }

    /**
     * @inheritdoc ICapacitor
     */
    function sealPacket(
        uint256
    ) external override onlySocket returns (bytes32, uint64) {
        uint64 packetCount = _nextSealCount++;
        if (_roots[packetCount] == bytes32(0)) revert NoPendingPacket();

        bytes32 root = _roots[packetCount];
        return (root, packetCount);
    }

    /**
     * @inheritdoc ICapacitor
     */
    function getNextPacketToBeSealed()
        external
        view
        override
        returns (bytes32, uint64)
    {
        uint64 toSeal = _nextSealCount;
        return (_roots[toSeal], toSeal);
    }

    /**
     * @dev Returns the root hash of the packet with the specified count.
     * @param count_ The count of the packet.
     * @return The root hash of the packet.
     */
    function getRootByCount(
        uint64 count_
    ) external view override returns (bytes32) {
        return _roots[count_];
    }
}

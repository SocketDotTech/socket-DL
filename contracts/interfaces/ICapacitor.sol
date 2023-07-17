// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

/**
 * @title ICapacitor
 * @dev Interface for a Capacitor contract that stores and manages messages in packets
 */
interface ICapacitor {
    /**
     * @notice adds the packed message to a packet
     * @dev this should be only executable by socket
     * @param packedMessage the message packed with payload, fees and config
     */
    function addPackedMessage(bytes32 packedMessage) external;

    /**
     * @notice returns the latest packet details which needs to be sealed
     * @return root root hash of the latest packet which is not yet sealed
     * @return packetCount latest packet id which is not yet sealed
     */
    function getNextPacketToBeSealed()
        external
        view
        returns (bytes32 root, uint64 packetCount);

    /**
     * @notice returns the root of packet for given id
     * @param id the id assigned to packet
     * @return root root hash corresponding to given id
     */
    function getRootByCount(uint64 id) external view returns (bytes32 root);

    /**
     * @notice returns the maxPacketLength
     * @return maxPacketLength of the capacitor
     */
    function getMaxPacketLength()
        external
        view
        returns (uint256 maxPacketLength);

    /**
     * @notice seals the packet
     * @dev indicates the packet is ready to be shipped and no more messages can be added now.
     * @dev this should be called by socket only
     * @param batchSize_ used with packet batching capacitors
     * @return root root hash of the packet
     * @return packetCount id of the packed sealed
     */
    function sealPacket(
        uint256 batchSize_
    ) external returns (bytes32 root, uint64 packetCount);
}

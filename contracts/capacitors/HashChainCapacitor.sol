// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./BaseCapacitor.sol";

/**
 * @title HashChainCapacitor
 * @dev A contract that implements ICapacitor and stores packed messages in a hash chain.
 * The hash chain is made of packets, each packet contains a capped number of messages.
 * Each new message added to the chain is hashed with the previous root to create a new root.
 * When a packet is full, a new packet is created and the root of the last packet is sealed.
 */
contract HashChainCapacitor is BaseCapacitor {
    uint64 private constant _MAX_LEN = 10;

    /// an incrementing count for each new message added
    uint64 internal _nextMessageCount;
    /// points to last message included in packet
    uint64 internal _messagePacked;
    // message count => root
    mapping(uint64 => bytes32) internal _messageRoots;

    // Error triggered when batch size is more than max length
    error InvalidBatchSize();
    // Error triggered when no message found or total message count is less than expected length
    error InsufficentMessageLength();

    /**
     * @notice emitted when a new message is added to a packet
     * @param packedMessage the message packed with payload, fees and config
     * @param messageCount an incremental id updates when a new message is added
     * @param packetCount an incremental id assigned to each new packet
     * @param newRootHash the packed message hash (to be replaced with the root hash of the merkle tree)
     */
    event MessageAdded(
        bytes32 packedMessage,
        uint64 messageCount,
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
     * @notice Adds a packed message to the hash chain.
     * @notice Only socket can call this function
     * @dev The packed message is added to the current packet and hashed with the previous root to create a new root.
     * If the packet is full, a new packet is created and the root of the last packet is finalised to be sealed.
     * @param packedMessage_ The packed message to be added to the hash chain.
     */
    function addPackedMessage(
        bytes32 packedMessage_
    ) external override onlySocket {
        uint64 messageCount = _nextMessageCount++;
        uint64 packetCount = _nextPacketCount;

        // index to get root for last message, if created first time, takes current index hence bytes32(0)
        uint64 rootIndex = messageCount == 0 ? 0 : messageCount - 1;

        // hash the packed message with last root and create a new root
        bytes32 root = keccak256(
            abi.encode(_messageRoots[rootIndex], packedMessage_)
        );
        // update the root for each new message added
        _messageRoots[messageCount] = root;

        // create a packet if max length is reached and update packet count
        if (_messagePacked - packetCount == _MAX_LEN)
            _createPacket(packetCount, messageCount, root);

        emit MessageAdded(packedMessage_, messageCount, packetCount, root);
    }

    /**
     * @dev Seals the next pending packet and returns its root hash and packet count.
     * @dev we use seal packet count to make sure there is no scope of censorship and all the packets get sealed.
     * @return root The root hash and packet count of the sealed packet.
     */
    function sealPacket(
        uint256 batchSize
    )
        external
        virtual
        override
        onlySocket
        returns (bytes32 root, uint64 packetCount)
    {
        uint256 messageCount = _nextMessageCount;

        // revert if batch size exceeds max length
        if (batchSize > _MAX_LEN) revert InvalidBatchSize();

        // if no message found or total message count is less than expected length
        if (messageCount <= _messagePacked + batchSize)
            revert InsufficentMessageLength();

        packetCount = _nextSealCount++;
        if (_roots[packetCount] == bytes32(0)) {
            // last message count included in this packet
            uint64 lastMessageCount = _messagePacked + uint64(batchSize);
            _createPacket(
                packetCount,
                lastMessageCount,
                _messageRoots[lastMessageCount]
            );
        }

        root = _roots[packetCount];
    }

    /**
     * @dev Returns the root hash and packet count of the next pending packet to be sealed.
     * @dev includes all the messages added till now if packet is not full yet
     * @return root The root hash and packet count of the next pending packet.
     */
    function getNextPacketToBeSealed()
        external
        view
        virtual
        override
        returns (bytes32 root, uint64 count)
    {
        count = _nextSealCount;

        uint64 lastMessageCount;
        if (_roots[count] == bytes32(0)) {
            // as addPackedMessage auto update _roots as max length is reached, hence length is not verified here
            lastMessageCount = _nextMessageCount == 0
                ? 0
                : _nextMessageCount - 1;
            root = _messageRoots[lastMessageCount];
        } else root = _roots[count];
    }

    function _createPacket(
        uint64 packetCount,
        uint64 messageCount,
        bytes32 root
    ) internal {
        // stores the root on given packet count and updated messages packed
        _roots[packetCount] = root;
        _messagePacked = messageCount;

        // increments total packet count
        _nextPacketCount++;
    }
}

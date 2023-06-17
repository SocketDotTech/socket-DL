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
    uint256 public maxPacketLength;

    /// an incrementing count for each new message added
    uint64 internal _nextMessageCount = 1;
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
        address owner_,
        uint256 maxPacketLength_
    ) BaseCapacitor(socket_, owner_) {
        _grantRole(RESCUE_ROLE, owner_);
        maxPacketLength = maxPacketLength_;
    }

    function updateMaxPacketLength(
        uint256 maxPacketLength_
    ) external onlyOwner {
        if (maxPacketLength_ < maxPacketLength) {
            uint256 packets = (_nextMessageCount - _messagePacked) %
                maxPacketLength_;

            for (uint256 index = 0; index < packets; ) {
                uint64 packetEndAt = _messagePacked + uint64(maxPacketLength_);
                _createPacket(
                    _nextPacketCount,
                    packetEndAt,
                    _messageRoots[packetEndAt]
                );
                unchecked {
                    index++;
                }
            }
        }
        maxPacketLength = maxPacketLength_;
    }

    function getMaxPacketLength() external view override returns (uint256) {
        return maxPacketLength;
    }

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

        // hash the packed message with last root and create a new root
        bytes32 root = keccak256(
            abi.encode(_messageRoots[messageCount - 1], packedMessage_)
        );
        // update the root for each new message added
        _messageRoots[messageCount] = root;

        // create a packet if max length is reached and update packet count
        if (messageCount - _messagePacked == maxPacketLength)
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
    ) external override onlySocket returns (bytes32 root, uint64 packetCount) {
        uint256 messageCount = _nextMessageCount;

        // revert if batch size exceeds max length
        if (batchSize > maxPacketLength) revert InvalidBatchSize();

        packetCount = _nextSealCount++;
        if (_roots[packetCount] == bytes32(0)) {
            // last message count included in this packet
            uint64 lastMessageCount = _messagePacked + uint64(batchSize);

            // if no message found or total message count is less than expected length
            if (messageCount <= lastMessageCount)
                revert InsufficentMessageLength();

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
        override
        returns (bytes32 root, uint64 count)
    {
        count = _nextSealCount;
        root = _getLatestRoot(count, 0);
    }

    /**
     * @dev Returns the root hash of the packet with the specified count.
     * @param count_ The count of the packet.
     * @return root The root hash of the packet.
     */
    function getRootByCount(
        uint64 count_
    ) external view override returns (bytes32) {
        return _getLatestRoot(count_, 0);
    }

    /**
     * @dev Returns the root hash and packet count of the next pending packet to be sealed with batch size.
     * @dev includes all the messages till `batchSize_` height from last msg packed
     * @param batchSize_ length of packet
     * @return root The root hash and packet count of the next pending packet.
     */
    function getNextPacketToBeSealed(
        uint256 batchSize_
    ) external view returns (bytes32 root, uint64 count) {
        count = _nextSealCount;
        root = _getLatestRoot(count, uint64(batchSize_));
    }

    function _getLatestRoot(
        uint64 count_,
        uint64 batchSize_
    ) internal view returns (bytes32 root) {
        if (_roots[count_] == bytes32(0)) {
            // as addPackedMessage auto update _roots as max length is reached, hence length is not verified here
            uint64 lastMessageCount = batchSize_ == 0
                ? _nextMessageCount - 1
                : _messagePacked + batchSize_;
            if (_nextMessageCount <= lastMessageCount) return bytes32(0);
            root = _messageRoots[lastMessageCount];
        } else root = _roots[count_];
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

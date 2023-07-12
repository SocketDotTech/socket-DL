// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "./BaseCapacitor.sol";

/**
 * @title HashChainCapacitor
 * @notice This is an experimental capacitor to make sure Socket can work with batches, proofs etc.
 * @notice When Socket needs batches with more than one packet, we will likely implement something like Merkle capacitor.
 * @dev A contract that stores packed messages in a hash chain.
 *      The hash chain is made of packets, each packet contains a capped number of messages.
 *      Each new message added to the chain is hashed with the previous root to create a new root.
 *      When a packet is full, a new packet is created and the root of the last packet is sealed.
 */
contract HashChainCapacitor is BaseCapacitor {
    uint256 private constant MAX_LEN = 10;
    uint256 public maxPacketLength;

    /// an incrementing count for each new message added
    uint64 public nextMessageCount = 1;
    /// points to last message included in packet
    uint64 public messagePacked;
    // message count => root
    mapping(uint64 => bytes32) public messageRoots;

    // Error triggered when batch size is more than max length
    error InvalidBatchSize();
    // Error triggered when no message found or total message count is less than expected length
    error InsufficientMessageLength();
    // Error triggered when packet length is more than max packet length supported
    error InvalidPacketLength();

    // Event triggered when max packet length is updated
    event MaxPacketLengthSet(uint256 maxPacketLength);

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
     * @param maxPacketLength_ The max Packet Length of the capacitor contract.
     */
    constructor(
        address socket_,
        address owner_,
        uint256 maxPacketLength_
    ) BaseCapacitor(socket_, owner_) {
        if (maxPacketLength > MAX_LEN) revert InvalidPacketLength();
        maxPacketLength = maxPacketLength_;
    }

    /**
     * @notice Update packet length of the hash chain capacitor.
     * @notice Only owner can call this function
     * @dev The function will update the packet length of the hash chain capacitor, and also create any packets
     * if the new packet length is less than the current packet length.
     * @param maxPacketLength_ The new nax packet length of the hash chain.
     */
    function updateMaxPacketLength(
        uint256 maxPacketLength_
    ) external onlyOwner {
        if (maxPacketLength > MAX_LEN) revert InvalidPacketLength();
        if (maxPacketLength_ < maxPacketLength) {
            uint64 lastPackedMsgIndex = messagePacked;
            uint64 packetCount = _nextPacketCount;
            uint64 packets = (nextMessageCount - lastPackedMsgIndex) %
                uint64(maxPacketLength_);

            _nextPacketCount += packets;

            for (uint64 index = 0; index < packets; ) {
                uint64 packetEndAt = lastPackedMsgIndex +
                    uint64(maxPacketLength_);

                _roots[packetCount + index] = messageRoots[packetEndAt];
                lastPackedMsgIndex = packetEndAt;
                unchecked {
                    ++index;
                }
            }
            messagePacked = lastPackedMsgIndex;
        }

        maxPacketLength = maxPacketLength_;
        emit MaxPacketLengthSet(maxPacketLength_);
    }

    /**
     * @inheritdoc ICapacitor
     */
    function getMaxPacketLength() external view override returns (uint256) {
        return maxPacketLength;
    }

    /**
     * @notice Adds a packed message to the hash chain.
     * @notice Only socket can call this function
     * @dev The packed message is added to the current packet and hashed with the previous root to create a new root.
     * If the packet is full, a new packet is created and the root of the last packet is finalized to be sealed.
     * @param packedMessage_ The packed message to be added to the hash chain.
     */
    function addPackedMessage(
        bytes32 packedMessage_
    ) external override onlySocket {
        uint64 messageCount = nextMessageCount++;
        uint64 packetCount = _nextPacketCount;

        // hash the packed message with last root and create a new root
        bytes32 root = keccak256(
            abi.encode(messageRoots[messageCount - 1], packedMessage_)
        );
        // update the root for each new message added
        messageRoots[messageCount] = root;

        // create a packet if max length is reached and update packet count
        if (messageCount - messagePacked == maxPacketLength)
            _createPacket(packetCount, messageCount, root);

        emit MessageAdded(packedMessage_, messageCount, packetCount, root);
    }

    /**
     * @dev Seals the next pending packet and returns its root hash and packet count.
     * @param batchSize we use seal packet count to make sure there is no scope of censorship and all the packets get sealed.
     * @return root The root hash and packet count of the sealed packet.
     */
    function sealPacket(
        uint256 batchSize
    ) external override onlySocket returns (bytes32 root, uint64 packetCount) {
        uint256 messageCount = nextMessageCount;

        // revert if batch size exceeds max length
        if (batchSize > maxPacketLength) revert InvalidBatchSize();

        packetCount = _nextSealCount++;
        if (_roots[packetCount] == bytes32(0)) {
            // last message count included in this packet
            uint64 lastMessageCount = messagePacked + uint64(batchSize);

            // if no message found or total message count is less than expected length
            if (messageCount <= lastMessageCount)
                revert InsufficientMessageLength();

            _createPacket(
                packetCount,
                lastMessageCount,
                messageRoots[lastMessageCount]
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
                ? nextMessageCount - 1
                : messagePacked + batchSize_;

            if (nextMessageCount <= lastMessageCount) return bytes32(0);
            root = messageRoots[lastMessageCount];
        } else root = _roots[count_];
    }

    function _createPacket(
        uint64 packetCount,
        uint64 messageCount,
        bytes32 root
    ) internal {
        // stores the root on given packet count and updated messages packed
        _roots[packetCount] = root;
        messagePacked = messageCount;

        // increments total packet count. we don't expect _nextPacketCount to reach the max value of uint256
        unchecked {
            _nextPacketCount++;
        }
    }
}

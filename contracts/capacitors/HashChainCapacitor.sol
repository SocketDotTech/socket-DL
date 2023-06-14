// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./BaseCapacitor.sol";

/**
 * @title HashChainCapacitor
 * @notice This is an experimental contract and have known bugs
 * @dev A contract that implements ICapacitor and stores packed messages in a hash chain.
 * The hash chain is made of packets, each packet contains a maximum of 10 messages.
 * Each new message added to the chain is hashed with the previous root to create a new root.
 * When a packet is full, a new packet is created and the root of the last packet is sealed.
 */
contract HashChainCapacitor is BaseCapacitor {
    uint64 private constant _MAX_LEN = 10;

    // msg count => root
    mapping(uint64 => bytes32) internal _tempRoots;

    /// an incrementing count for each new packet created
    uint64 internal _nextMessageCount;
    uint64 internal _msgPacked;

    error InvalidBatchSize();

    /**
     * @notice emitted when a new message is added to a packet
     * @param packedMessage the message packed with payload, fees and config
     * @param packetCount an incremental id assigned to each new packet
     * @param newRootHash the packed message hash (to be replaced with the root hash of the merkle tree)
     */
    event MessageAdded(
        bytes32 packedMessage,
        uint64 msgCount,
        uint64 packetCount,
        bytes32 newRootHash
    );

    /**
     * @notice Initializes the HashChainCapacitor contract with a socket address.
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
     * @notice Adds a packed message to the hash chain.
     * @dev The packed message is added to the current packet and hashed with the previous root to create a new root.
     * If the packet is full, a new packet is created and the root of the last packet is sealed.
     * @param packedMessage_ The packed message to be added to the hash chain.
     */
    function addPackedMessage(
        bytes32 packedMessage_
    ) external override onlySocket {
        uint64 msgCount = _nextMessageCount++;
        uint64 packetCount = _nextPacketCount;
        uint64 rootIndex = msgCount == 0 ? 0 : msgCount - 1;

        bytes32 root = keccak256(
            abi.encode(_tempRoots[rootIndex], packedMessage_)
        );

        if (_msgPacked - packetCount == _MAX_LEN)
            _createPacket(packetCount, msgCount, root);

        _tempRoots[msgCount] = root;
        emit MessageAdded(packedMessage_, msgCount, packetCount, root);
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
        uint256 msgCount = _nextMessageCount;
        if (batchSize > _MAX_LEN || msgCount <= _msgPacked + batchSize)
            revert InvalidBatchSize();

        if (msgCount == 0) revert NoPendingPacket();
        packetCount = _nextSealCount++;

        if (_roots[packetCount] == bytes32(0)) {
            uint64 lastMsgIndex = _msgPacked + uint64(batchSize);
            _createPacket(packetCount, lastMsgIndex, _tempRoots[lastMsgIndex]);
        }

        root = _roots[packetCount];
    }

    function _createPacket(
        uint64 packetCount,
        uint64 msgCount,
        bytes32 root
    ) internal {
        _roots[packetCount] = root;
        _msgPacked = msgCount;
        _nextPacketCount++;
    }
}

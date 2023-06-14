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
    uint256 private _chainLength;
    uint256 private constant _MAX_LEN = 10;
    uint256 public maxPacketLength;

    /**
     * @notice Initializes the HashChainCapacitor contract with a socket address.
     * @param socket_ The address of the socket contract
     * @param owner_ The address of the contract owner
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
        maxPacketLength = maxPacketLength_;
    }

    function getMaxPacketLength() external view override returns (uint256) {
        return maxPacketLength;
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
        uint64 packetCount = _nextPacketCount;

        _roots[packetCount] = keccak256(
            abi.encode(_roots[packetCount], packedMessage_)
        );
        _chainLength++;

        if (_chainLength == _MAX_LEN) {
            _nextPacketCount++;
            _chainLength = 0;
        }

        emit MessageAdded(packedMessage_, packetCount, _roots[packetCount]);
    }
}

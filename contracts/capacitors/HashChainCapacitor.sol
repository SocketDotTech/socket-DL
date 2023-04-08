// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./BaseCapacitor.sol";

contract HashChainCapacitor is BaseCapacitor {
    uint256 private _chainLength;
    uint256 private constant _MAX_LEN = 10;

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
        uint256 packetCount = _nextPacketCount;

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

    function sealPacket(
        uint256
    ) external virtual override onlySocket returns (bytes32, uint256) {
        uint256 packetCount = _nextSealCount++;

        if (_roots[packetCount] == bytes32(0)) revert NoPendingPacket();
        bytes32 root = _roots[packetCount];

        return (root, packetCount);
    }
}

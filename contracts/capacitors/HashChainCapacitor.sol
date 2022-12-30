// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./BaseCapacitor.sol";

contract HashChainCapacitor is BaseCapacitor {
    uint256 private _chainLength;
    uint256 private constant MAX_LEN = 10;

    /**
     * @notice initialises the contract with socket address
     */
    constructor(address socket_) BaseCapacitor(socket_) {}

    /// adds the packed message to a packet
    /// @inheritdoc ICapacitor
    function addPackedMessage(
        bytes32 packedMessage
    ) external override onlyRole(SOCKET_ROLE) {
        uint256 packetId = _packets;

        _roots[packetId] = keccak256(
            abi.encode(_roots[packetId], packedMessage)
        );
        _chainLength++;

        if (_chainLength == MAX_LEN) {
            _packets++;
            _chainLength = 0;
        }

        emit MessageAdded(packedMessage, packetId, _roots[packetId]);
    }

    function sealPacket()
        external
        virtual
        override
        onlyRole(SOCKET_ROLE)
        returns (bytes32, uint256)
    {
        uint256 packetId = _sealedPackets;

        if (_roots[packetId] == bytes32(0)) revert NoPendingPacket();
        bytes32 root = _roots[packetId];
        _sealedPackets++;

        emit PacketComplete(root, packetId);
        return (root, packetId);
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../BaseAccum.sol";
import "../../interfaces/INotary.sol";

abstract contract NativeBridgeAccum is BaseAccum {
    address public remoteNotary;
    uint256 public immutable _chainSlug;

    event UpdatedNotary(address notary_);

    constructor(
        address socket_,
        address notary_,
        uint32 remoteChainSlug_,
        uint32 chainSlug_
    ) BaseAccum(socket_, notary_, remoteChainSlug_) {
        _chainSlug = chainSlug_;
    }

    function _sendMessage(uint256[] calldata bridgeParams, bytes memory data)
        internal
        virtual;

    function sealPacket(uint256[] calldata bridgeParams)
        external
        payable
        override
        onlyRole(NOTARY_ROLE)
        returns (
            bytes32,
            uint256,
            uint256
        )
    {
        uint256 packetId = _sealedPackets++;
        bytes32 root = _roots[packetId];
        if (root == bytes32(0)) revert NoPendingPacket();

        bytes memory data = abi.encodeWithSelector(
            INotary.attest.selector,
            _getPacketId(packetId),
            root,
            bytes("")
        );

        _sendMessage(bridgeParams, data);

        emit PacketComplete(root, packetId);
        return (root, packetId, remoteChainSlug);
    }

    function addPackedMessage(bytes32 packedMessage)
        external
        override
        onlyRole(SOCKET_ROLE)
    {
        uint256 packetId = _packets;
        _roots[packetId] = packedMessage;
        _packets++;

        emit MessageAdded(packedMessage, packetId, packedMessage);
    }

    function setRemoteNotary(address notary_) external onlyOwner {
        remoteNotary = notary_;
        emit UpdatedNotary(notary_);
    }

    function _getPacketId(uint256 packetCount_)
        internal
        view
        returns (uint256 packetId)
    {
        packetId =
            (_chainSlug << 224) |
            (uint256(uint160(address(this))) << 64) |
            packetCount_;
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./BaseAccum.sol";
import "../interfaces/INotary.sol";
import "../interfaces/native-bridge/IInbox.sol";

contract ArbitrumL1Accum is BaseAccum {
    address public remoteNotary;
    address public remoteRefundAddress;
    address public callValueRefundAddress;

    uint256 public immutable _chainSlug;
    IInbox public inbox;

    event RetryableTicketCreated(uint256 indexed ticketId);

    constructor(
        address socket_,
        address notary_,
        address inbox_,
        uint32 remoteChainSlug_,
        uint32 chainSlug_
    ) BaseAccum(socket_, notary_, remoteChainSlug_) {
        inbox = IInbox(inbox_);

        _chainSlug = chainSlug_;
        remoteRefundAddress = msg.sender;
        callValueRefundAddress = msg.sender;
    }

    function setRemoteNotary(address notary_) external onlyOwner {
        remoteNotary = notary_;
    }

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
        if (_roots[_sealedPackets] == bytes32(0)) revert NoPendingPacket();
        bytes memory data = abi.encodeWithSelector(
            INotary.attest.selector,
            _getPacketId(_sealedPackets),
            _roots[_sealedPackets],
            bytes("")
        );

        sendL2Message(bridgeParams, data);

        emit PacketComplete(_roots[_sealedPackets], _sealedPackets);
        return (_roots[_sealedPackets], _sealedPackets++, remoteChainSlug);
    }

    function sendL2Message(uint256[] calldata bridgeParams, bytes memory data)
        internal
    {
        // to avoid stack too deep
        address callValueRefund = callValueRefundAddress;
        address remoteRefund = remoteRefundAddress;

        uint256 ticketID = inbox.createRetryableTicket{value: msg.value}(
            remoteNotary,
            0, // no value needed for attest
            bridgeParams[0], // maxSubmissionCost
            remoteRefund,
            callValueRefund,
            bridgeParams[1], // maxGas
            bridgeParams[2], // gasPriceBid
            data
        );
        emit RetryableTicketCreated(ticketID);
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
}

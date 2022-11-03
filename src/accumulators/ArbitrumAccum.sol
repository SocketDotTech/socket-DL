// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./BaseAccum.sol";
import "../interfaces/INotary.sol";
import "../interfaces/native-bridge/IInbox.sol";
import "../interfaces/native-bridge/IOutbox.sol";

contract ArbitrumAccum is BaseAccum {
    address public l2Notary;
    uint256 public maxSubmissionCost = 1000;
    uint256 public maxGas = 1000;
    uint256 public gasPriceBid = 1000;
    address public remoteRefundAddress = address(1);
    address public callValueRefundAddress = address(2);
    IInbox public inbox;

    event RetryableTicketCreated(uint256 indexed ticketId);

    constructor(
        address socket_,
        address notary_,
        address inbox_,
        address l2Notary_,
        uint32 remoteChainSlug_
    ) BaseAccum(socket_, notary_, remoteChainSlug_) {
        l2Notary = l2Notary_;
        inbox = IInbox(inbox_);
    }

    function sealPacket(
        uint256[] calldata bridgeParams,
        bytes calldata signature_
    )
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
            _sealedPackets,
            _roots[_sealedPackets],
            signature_
        );
        uint256 ticketID = sendL2Message(bridgeParams, data);

        emit RetryableTicketCreated(ticketID);
        emit PacketComplete(_roots[_sealedPackets], _sealedPackets);
        return (_roots[_sealedPackets], _sealedPackets++, remoteChainSlug);
    }

    function sendL2Message(uint256[] calldata bridgeParams, bytes memory data)
        internal
        returns (uint256 ticketID)
    {
        ticketID = inbox.createRetryableTicket{value: msg.value}(
            l2Notary,
            0, // no value needed for attest
            bridgeParams[0], // maxSubmissionCost
            remoteRefundAddress,
            callValueRefundAddress,
            bridgeParams[1], // maxGas
            bridgeParams[2], // gasPriceBid
            data
        );
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

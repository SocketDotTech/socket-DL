// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./BaseAccum.sol";
import "../interfaces/INotary.sol";
import "../interfaces/native-bridge/IInbox.sol";

contract ArbitrumL1Accum is BaseAccum {
    address public remoteNotary;
    address public remoteRefundAddress;
    address public callValueRefundAddress;
    IInbox public inbox;

    event RetryableTicketCreated(uint256 indexed ticketId);

    constructor(
        address socket_,
        address notary_,
        address inbox_,
        uint32 remoteChainSlug_
    ) BaseAccum(socket_, notary_, remoteChainSlug_) {
        inbox = IInbox(inbox_);
        remoteRefundAddress = msg.sender;
        callValueRefundAddress = msg.sender;
    }

    function setRemoteNotary(address notary_) external onlyOwner {
        remoteNotary = notary_;
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
        sendL2Message(bridgeParams, signature_);

        emit PacketComplete(_roots[_sealedPackets], _sealedPackets);
        return (_roots[_sealedPackets], _sealedPackets++, remoteChainSlug);
    }

    function sendL2Message(
        uint256[] calldata bridgeParams,
        bytes calldata signature_
    ) internal {
        uint256 ticketID = inbox.createRetryableTicket{value: msg.value}(
            remoteNotary,
            0, // no value needed for attest
            bridgeParams[0], // maxSubmissionCost
            remoteRefundAddress,
            callValueRefundAddress,
            bridgeParams[1], // maxGas
            bridgeParams[2], // gasPriceBid
            abi.encodeWithSelector(
                INotary.attest.selector,
                _sealedPackets,
                _roots[_sealedPackets],
                signature_
            )
        );

        emit RetryableTicketCreated(ticketID);
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

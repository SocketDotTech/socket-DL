// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../NativeBridgeAccum.sol";
import "../../../interfaces/native-bridge/IInbox.sol";

contract ArbitrumL1Accum is NativeBridgeAccum {
    address public remoteRefundAddress;
    address public callValueRefundAddress;
    IInbox public inbox;

    event UpdatedInboxAddress(address inbox_);
    event UpdatedRefundAddresses(
        address remoteRefundAddress_,
        address callValueRefundAddress_
    );

    constructor(
        address socket_,
        address notary_,
        address inbox_,
        uint32 remoteChainSlug_,
        uint32 chainSlug_
    ) NativeBridgeAccum(socket_, notary_, remoteChainSlug_, chainSlug_) {
        inbox = IInbox(inbox_);
        remoteRefundAddress = msg.sender;
        callValueRefundAddress = msg.sender;
    }

    function _sendMessage(uint256[] calldata bridgeParams, bytes memory data)
        internal
        override
    {
        // to avoid stack too deep
        address callValueRefund = callValueRefundAddress;
        address remoteRefund = remoteRefundAddress;

        inbox.createRetryableTicket{value: msg.value}(
            remoteNotary,
            0, // no value needed for attest
            bridgeParams[0], // maxSubmissionCost
            remoteRefund,
            callValueRefund,
            bridgeParams[1], // maxGas
            bridgeParams[2], // gasPriceBid
            data
        );
    }

    function updateRefundAddresses(
        address remoteRefundAddress_,
        address callValueRefundAddress_
    ) external onlyOwner {
        remoteRefundAddress = remoteRefundAddress_;
        callValueRefundAddress = callValueRefundAddress_;

        emit UpdatedRefundAddresses(
            remoteRefundAddress_,
            callValueRefundAddress_
        );
    }

    function updateInboxAddresses(address inbox_) external onlyOwner {
        inbox = IInbox(inbox_);

        emit UpdatedInboxAddress(inbox_);
    }
}

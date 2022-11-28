// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../../interfaces/native-bridge/IInbox.sol";
import "../../interfaces/native-bridge/IOutbox.sol";
import "../../interfaces/native-bridge/IArbSys.sol";
import "../../interfaces/native-bridge/IBridge.sol";
import "../../libraries/AddressAliasHelper.sol";
import "./NativeBridgeNotary.sol";

contract ArbitrumNotary is NativeBridgeNotary {
    address public remoteRefundAddress;
    address public callValueRefundAddress;
    bool public isL2;

    IInbox public inbox;
    IArbSys constant arbsys = IArbSys(address(100));

    event UpdatedInboxAddress(address inbox_);
    event UpdatedRefundAddresses(
        address remoteRefundAddress_,
        address callValueRefundAddress_
    );

    modifier onlyRemoteAccumulator() override {
        if (isL2) {
            if (msg.sender != AddressAliasHelper.applyL1ToL2Alias(remoteNotary))
                revert InvalidAttester();
        } else {
            IBridge bridge = inbox.bridge();
            if (msg.sender != address(bridge)) revert InvalidSender();

            IOutbox outbox = IOutbox(bridge.activeOutbox());
            address l2Sender = outbox.l2ToL1Sender();
            if (l2Sender != remoteNotary) revert InvalidAttester();
        }
        _;
    }

    constructor(
        address signatureVerifier_,
        uint32 chainSlug_,
        address remoteNotary_,
        address inbox_
    ) NativeBridgeNotary(signatureVerifier_, chainSlug_, remoteNotary_) {
        isL2 = (block.chainid == 42161 || block.chainid == 421613)
            ? true
            : false;
        inbox = IInbox(inbox_);

        remoteRefundAddress = msg.sender;
        callValueRefundAddress = msg.sender;
    }

    function _sendMessage(
        uint256[] calldata bridgeParams,
        uint256 packetId,
        bytes32 root
    ) internal override {
        bytes memory data = abi.encodeWithSelector(
            INotary.attest.selector,
            packetId,
            root,
            bytes("")
        );

        if (isL2) {
            arbsys.sendTxToL1(remoteNotary, data);
        } else {
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

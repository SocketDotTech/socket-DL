// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../../interfaces/native-bridge/IInbox.sol";
import "../../interfaces/native-bridge/IOutbox.sol";
import "../../interfaces/native-bridge/IBridge.sol";
import "../../libraries/AddressAliasHelper.sol";
import {NativeBridgeNotary} from "./NativeBridgeNotary.sol";

contract ArbitrumReceiver is NativeBridgeNotary {
    IInbox public inbox;
    bool public isL2;

    modifier onlyRemoteAccumulator() override {
        if (isL2) {
            if (remoteTarget != AddressAliasHelper.applyL1ToL2Alias(msg.sender))
                revert InvalidAttester();
        } else {
            IBridge bridge = inbox.bridge();
            if (msg.sender != address(bridge)) revert InvalidSender();

            IOutbox outbox = IOutbox(bridge.activeOutbox());
            address l2Sender = outbox.l2ToL1Sender();
            if (l2Sender != remoteTarget) revert InvalidAttester();
        }
        _;
    }

    constructor(
        address signatureVerifier_,
        uint32 chainSlug_,
        address remoteTarget_,
        address inbox_
    ) NativeBridgeNotary(signatureVerifier_, chainSlug_, remoteTarget_) {
        isL2 = (block.chainid == 42161 || block.chainid == 421613)
            ? true
            : false;
        inbox = IInbox(inbox_);
    }
}

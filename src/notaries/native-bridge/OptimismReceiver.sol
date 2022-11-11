// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../../interfaces/native-bridge/ICrossDomainMessenger.sol";
import {NativeBridgeNotary} from "./NativeBridgeNotary.sol";

contract OptimismReceiver is NativeBridgeNotary {
    address public immutable OVM_L2_CROSS_DOMAIN_MESSENGER;
    bool public isL2;

    modifier onlyRemoteAccumulator() override {
        if (isL2) {
            if (
                msg.sender != OVM_L2_CROSS_DOMAIN_MESSENGER ||
                ICrossDomainMessenger(OVM_L2_CROSS_DOMAIN_MESSENGER)
                    .xDomainMessageSender() !=
                remoteTarget
            ) revert InvalidSender();
        } else {
            // for l2 to l1
        }
        _;
    }

    constructor(
        address ovmL2CrossDomainMessenger,
        address signatureVerifier_,
        uint32 chainSlug_,
        address remoteTarget_
    ) NativeBridgeNotary(signatureVerifier_, chainSlug_, remoteTarget_) {
        isL2 = (block.chainid == 10 || block.chainid == 420) ? true : false;
        OVM_L2_CROSS_DOMAIN_MESSENGER = ovmL2CrossDomainMessenger;
    }
}

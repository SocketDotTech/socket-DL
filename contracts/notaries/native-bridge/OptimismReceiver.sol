// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../../interfaces/native-bridge/ICrossDomainMessenger.sol";
import {NativeBridgeNotary} from "./NativeBridgeNotary.sol";

contract OptimismReceiver is NativeBridgeNotary {
    address public OVM_L2_CROSS_DOMAIN_MESSENGER;
    bool public isL2;

    modifier onlyRemoteAccumulator() override {
        if (
            msg.sender != OVM_L2_CROSS_DOMAIN_MESSENGER &&
            ICrossDomainMessenger(OVM_L2_CROSS_DOMAIN_MESSENGER)
                .xDomainMessageSender() !=
            remoteTarget
        ) revert InvalidSender();
        _;
    }

    constructor(
        address signatureVerifier_,
        uint32 chainSlug_,
        address remoteTarget_
    ) NativeBridgeNotary(signatureVerifier_, chainSlug_, remoteTarget_) {
        if ((block.chainid == 10 || block.chainid == 420)) {
            isL2 = true;
            OVM_L2_CROSS_DOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007;
        } else {
            OVM_L2_CROSS_DOMAIN_MESSENGER = block.chainid == 1
                ? 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1
                : 0x5086d1eEF304eb5284A0f6720f79403b4e9bE294;
        }
    }
}

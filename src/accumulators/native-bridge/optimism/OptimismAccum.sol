// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../NativeBridgeAccum.sol";
import "../../../interfaces/native-bridge/ICrossDomainMessenger.sol";

contract OptimismAccum is NativeBridgeAccum {
    ICrossDomainMessenger public crossDomainMessenger;

    constructor(
        address socket_,
        address notary_,
        uint32 remoteChainSlug_,
        uint32 chainSlug_
    ) NativeBridgeAccum(socket_, notary_, remoteChainSlug_, chainSlug_) {
        if ((block.chainid == 10 || block.chainid == 420)) {
            crossDomainMessenger = ICrossDomainMessenger(
                0x4200000000000000000000000000000000000007
            );
        } else {
            crossDomainMessenger = block.chainid == 1
                ? ICrossDomainMessenger(
                    0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1
                )
                : ICrossDomainMessenger(
                    0x5086d1eEF304eb5284A0f6720f79403b4e9bE294
                );
        }
    }

    /**
     * @param bridgeParams - only one index, gas limit needed to execute data
     * @param data - encoded data to be sent to remote notary
     */
    function _sendMessage(
        uint256[] calldata bridgeParams,
        bytes memory data
    ) internal override {
        crossDomainMessenger.sendMessage(
            remoteNotary,
            data,
            uint32(bridgeParams[0])
        );
    }
}

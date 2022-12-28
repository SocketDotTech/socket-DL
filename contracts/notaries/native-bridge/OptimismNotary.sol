// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../../interfaces/native-bridge/ICrossDomainMessenger.sol";
import "./NativeBridgeNotary.sol";

contract OptimismNotary is NativeBridgeNotary {
    ICrossDomainMessenger public crossDomainMessenger;
    bool public isL2;

    modifier onlyRemoteCapacitor() override {
        if (
            msg.sender != address(crossDomainMessenger) &&
            crossDomainMessenger.xDomainMessageSender() != remoteNotary
        ) revert InvalidSender();
        _;
    }

    constructor(
        address signatureVerifier_,
        uint32 chainSlug_,
        address remoteNotary_
    ) NativeBridgeNotary(signatureVerifier_, chainSlug_, remoteNotary_) {
        if ((block.chainid == 10 || block.chainid == 420)) {
            isL2 = true;
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
     */
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

        crossDomainMessenger.sendMessage(
            remoteNotary,
            data,
            uint32(bridgeParams[0])
        );
    }
}

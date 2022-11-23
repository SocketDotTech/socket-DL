// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import {NativeBridgeNotary} from "./NativeBridgeNotary.sol";
import "fx-portal/tunnel/FxBaseRootTunnel.sol";

contract PolygonRootReceiver is NativeBridgeNotary, FxBaseRootTunnel {
    modifier onlyRemoteAccumulator() override {
        _;
    }

    constructor(
        address checkpointManager_,
        address fxRoot_,
        address signatureVerifier_,
        uint32 chainSlug_,
        address remoteTarget_
    )
        NativeBridgeNotary(signatureVerifier_, chainSlug_, remoteTarget_)
        FxBaseRootTunnel(checkpointManager_, fxRoot_)
    {}

    function _processMessageFromChild(
        bytes memory data
    ) internal override onlyRemoteAccumulator {
        (uint256 packetId, bytes32 root, ) = abi.decode(
            data,
            (uint256, bytes32, bytes)
        );
        _attest(packetId, root);
    }
}

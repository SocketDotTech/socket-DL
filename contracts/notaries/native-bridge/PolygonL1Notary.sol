// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import {NativeBridgeNotary} from "./NativeBridgeNotary.sol";
import "fx-portal/tunnel/FxBaseRootTunnel.sol";

contract PolygonL1Notary is NativeBridgeNotary, FxBaseRootTunnel {
    event FxRootTunnel(address fxRootTunnel, address fxRootTunnel_);

    modifier onlyRemoteAccumulator() override {
        _;
    }

    constructor(
        address checkpointManager_,
        address fxRoot_,
        address signatureVerifier_,
        uint32 chainSlug_,
        address remoteNotary_
    )
        NativeBridgeNotary(signatureVerifier_, chainSlug_, remoteNotary_)
        FxBaseRootTunnel(checkpointManager_, fxRoot_)
    {}

    function _processMessageFromChild(
        bytes memory message
    ) internal override onlyRemoteAccumulator {
        (, , bytes memory data) = abi.decode(
            message,
            (uint256, bytes32, bytes)
        );
        (uint256 packetId, bytes32 root, ) = abi.decode(
            data,
            (uint256, bytes32, bytes)
        );
        _attest(packetId, root);
    }

    /**
     * @param packetId - packet id
     * @param root - root hash
     */
    function _sendMessage(
        uint256[] calldata,
        uint256 packetId,
        bytes32 root
    ) internal override {
        bytes memory data = abi.encode(packetId, root, bytes(""));
        bytes memory fxData = abi.encode(address(this), remoteNotary, data);
        _sendMessageToChild(fxData);
    }

    // set fxChildTunnel if not set already
    function updateFxChildTunnel(address fxChildTunnel_) external onlyOwner {
        emit FxRootTunnel(fxChildTunnel, fxChildTunnel_);
        fxChildTunnel = fxChildTunnel_;
    }
}

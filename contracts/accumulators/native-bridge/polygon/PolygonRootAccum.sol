// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../NativeBridgeAccum.sol";
import "fx-portal/tunnel/FxBaseRootTunnel.sol";

contract PolygonRootAccum is NativeBridgeAccum, FxBaseRootTunnel {
    constructor(
        address checkpointManager_,
        address fxRoot_,
        address socket_,
        address notary_,
        uint32 remoteChainSlug_,
        uint32 chainSlug_
    )
        NativeBridgeAccum(socket_, notary_, remoteChainSlug_, chainSlug_)
        FxBaseRootTunnel(checkpointManager_, fxRoot_)
    {}

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

    function _processMessageFromChild(bytes memory message) internal override {
        revert("Cannot process message here!");
    }
}

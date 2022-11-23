// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../NativeBridgeAccum.sol";
import "fx-portal/tunnel/FxBaseChildTunnel.sol";

contract PolygonChildAccum is NativeBridgeAccum, FxBaseChildTunnel {
    constructor(
        address fxChild_,
        address socket_,
        address notary_,
        uint32 remoteChainSlug_,
        uint32 chainSlug_
    )
        NativeBridgeAccum(socket_, notary_, remoteChainSlug_, chainSlug_)
        FxBaseChildTunnel(fxChild_)
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
        _sendMessageToRoot(fxData);
    }

    function _processMessageFromRoot(
        uint256 stateId,
        address sender,
        bytes memory message
    ) internal override {
        revert("Cannot process message here!");
    }
}

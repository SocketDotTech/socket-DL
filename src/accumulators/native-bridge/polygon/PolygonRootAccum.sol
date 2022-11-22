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
     * @param data - encoded data to be sent to remote notary
     */
    function _sendMessage(uint256[] calldata, bytes memory data)
        internal
        override
    {
        bytes memory fxData = abi.encode(address(this), remoteNotary, data);
        _sendMessageToChild(fxData);
    }

    function _processMessageFromChild(bytes memory message) internal override {
        revert("Cannot process message here!");
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "fx-portal/tunnel/FxBaseRootTunnel.sol";
import "../interfaces/native-bridge/INativeInitiator.sol";
import "../interfaces/native-bridge/INativeSwitchboard.sol";
import "../interfaces/ISocket.sol";

import "../utils/Ownable.sol";

contract PolygonL1NativeInitiator is
    INativeInitiator,
    Ownable(msg.sender),
    FxBaseRootTunnel
{
    address public remoteNativeSwitchboard;
    ISocket public socket;

    event FxRootTunnel(address fxRootTunnel, address fxRootTunnel_);
    event UpdatedRemoteNativeSwitchboard(address remoteNativeSwitchboard_);
    event UpdatedSocket(address socket);

    error NoRootFound();

    constructor(
        ISocket socket_,
        address checkpointManager_,
        address fxRoot_,
        address remoteNativeSwitchboard_
    ) FxBaseRootTunnel(checkpointManager_, fxRoot_) {
        socket = socket_;
        remoteNativeSwitchboard = remoteNativeSwitchboard_;
    }

    /**
     * @param packetId - packet id
     */
    function initateNativeConfirmation(
        uint256 packetId
    ) external payable override {
        bytes32 root = socket.remoteRoots(packetId);
        if (root == bytes32(0)) revert NoRootFound();

        bytes memory data = abi.encode(packetId, root);
        _sendMessageToChild(data);
    }

    function _processMessageFromChild(bytes memory) internal override {
        revert();
    }

    // set fxChildTunnel if not set already
    function updateFxChildTunnel(address fxChildTunnel_) external onlyOwner {
        emit FxRootTunnel(fxChildTunnel, fxChildTunnel_);
        fxChildTunnel = fxChildTunnel_;
    }

    function updateRemoteNativeSwitchboard(
        address remoteNativeSwitchboard_
    ) external onlyOwner {
        remoteNativeSwitchboard = remoteNativeSwitchboard_;
        emit UpdatedRemoteNativeSwitchboard(remoteNativeSwitchboard_);
    }

    function updateSocket(address socket_) external onlyOwner {
        socket = ISocket(socket_);
        emit UpdatedSocket(socket_);
    }
}

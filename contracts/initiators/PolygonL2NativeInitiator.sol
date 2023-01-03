// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "fx-portal/tunnel/FxBaseChildTunnel.sol";
import "../interfaces/native-bridge/INativeInitiator.sol";
import "../interfaces/native-bridge/INativeSwitchboard.sol";
import "../interfaces/ISocket.sol";

import "../utils/Ownable.sol";

contract PolygonL2NativeInitiator is
    INativeInitiator,
    Ownable(msg.sender),
    FxBaseChildTunnel
{
    address public remoteNativeSwitchboard;
    ISocket public socket;

    event UpdatedRemoteNativeSwitchboard(address remoteNativeSwitchboard_);
    event UpdatedSocket(address socket);
    event FxChildUpdate(address oldFxChild, address newFxChild);
    event FxRootTunnel(address fxRootTunnel, address fxRootTunnel_);

    error NoRootFound();

    constructor(
        ISocket socket_,
        address remoteNativeSwitchboard_,
        address fxChild_
    ) FxBaseChildTunnel(fxChild_) {
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
        _sendMessageToRoot(data);
    }

    function _processMessageFromRoot(
        uint256,
        address,
        bytes memory
    ) internal override {
        revert();
    }

    /**
     * @notice Update the address of the FxChild
     * @param fxChild_ The address of the new FxChild
     **/
    function updateFxChild(address fxChild_) external onlyOwner {
        emit FxChildUpdate(fxChild, fxChild_);
        fxChild = fxChild_;
    }

    function updateFxRootTunnel(address fxRootTunnel_) external onlyOwner {
        emit FxRootTunnel(fxRootTunnel, fxRootTunnel_);
        fxRootTunnel = fxRootTunnel_;
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

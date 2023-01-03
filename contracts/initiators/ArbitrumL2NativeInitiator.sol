// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/native-bridge/IArbSys.sol";
import "../interfaces/native-bridge/INativeInitiator.sol";
import "../interfaces/native-bridge/INativeSwitchboard.sol";
import "../interfaces/ISocket.sol";

import "../utils/Ownable.sol";

contract ArbitrumL2NativeInitiator is INativeInitiator, Ownable(msg.sender) {
    address public remoteNativeSwitchboard;

    IArbSys constant arbsys = IArbSys(address(100));
    ISocket public socket;

    event UpdatedRemoteNativeSwitchboard(address remoteNativeSwitchboard_);
    event UpdatedSocket(address socket);

    error NoRootFound();

    constructor(address remoteNativeSwitchboard_, ISocket socket_) {
        socket = socket_;
        remoteNativeSwitchboard = remoteNativeSwitchboard_;
    }

    function initateNativeConfirmation(
        uint256 packetId
    ) external payable override {
        bytes32 root = socket.remoteRoots(packetId);
        if (root == bytes32(0)) revert NoRootFound();

        bytes memory data = abi.encodeWithSelector(
            INativeSwitchboard.receivePacket.selector,
            packetId,
            root
        );

        arbsys.sendTxToL1(remoteNativeSwitchboard, data);
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

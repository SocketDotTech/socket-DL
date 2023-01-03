// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/native-bridge/ICrossDomainMessenger.sol";
import "../interfaces/native-bridge/INativeInitiator.sol";
import "../interfaces/native-bridge/INativeSwitchboard.sol";
import "../interfaces/ISocket.sol";

import "../utils/Ownable.sol";

contract OptimismNativeInitiator is INativeInitiator, Ownable(msg.sender) {
    uint256 public receivePacketGasLimit;
    address public remoteNativeSwitchboard;

    ICrossDomainMessenger public crossDomainMessenger;
    ISocket public socket;

    event UpdatedRemoteNativeSwitchboard(address remoteNativeSwitchboard_);
    event UpdatedReceivePacketGasLimit(uint256 receivePacketGasLimit_);
    event UpdatedSocket(address socket);

    error NoRootFound();

    constructor(
        uint256 receivePacketGasLimit_,
        address remoteNativeSwitchboard_,
        ISocket socket_
    ) {
        receivePacketGasLimit = receivePacketGasLimit_;
        remoteNativeSwitchboard = remoteNativeSwitchboard_;
        socket = socket_;

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

        crossDomainMessenger.sendMessage(
            remoteNativeSwitchboard,
            data,
            uint32(receivePacketGasLimit)
        );
    }

    function updateRemoteNativeSwitchboard(
        address remoteNativeSwitchboard_
    ) external onlyOwner {
        remoteNativeSwitchboard = remoteNativeSwitchboard_;
        emit UpdatedRemoteNativeSwitchboard(remoteNativeSwitchboard_);
    }

    function updateReceivePacketGasLimit(
        uint256 receivePacketGasLimit_
    ) external onlyOwner {
        receivePacketGasLimit = receivePacketGasLimit_;
        emit UpdatedReceivePacketGasLimit(receivePacketGasLimit_);
    }

    function updateSocket(address socket_) external onlyOwner {
        socket = ISocket(socket_);
        emit UpdatedSocket(socket_);
    }
}

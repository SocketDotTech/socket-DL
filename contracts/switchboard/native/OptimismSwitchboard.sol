// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../../interfaces/native-bridge/ICrossDomainMessenger.sol";
import "../../interfaces/ISocket.sol";
import "./NativeSwitchboardBase.sol";

contract OptimismSwitchboard is NativeSwitchboardBase {
    uint256 public receivePacketGasLimit;
    address public remoteNativeSwitchboard;
    // stores the roots received from native bridge
    mapping(uint256 => bytes32) public roots;

    ICrossDomainMessenger public crossDomainMessenger;
    ISocket public socket;

    event UpdatedRemoteNativeSwitchboard(address remoteNativeSwitchboard_);
    event UpdatedReceivePacketGasLimit(uint256 receivePacketGasLimit_);
    event UpdatedSocket(address socket);
    event RootReceived(uint256 packetId_, bytes32 root_);

    error InvalidSender();
    error NoRootFound();

    modifier onlyRemoteSwitchboard() {
        if (
            msg.sender != address(crossDomainMessenger) &&
            crossDomainMessenger.xDomainMessageSender() !=
            remoteNativeSwitchboard
        ) revert InvalidSender();
        _;
    }

    constructor(
        uint32 chainSlug_,
        uint256 receivePacketGasLimit_,
        address remoteNativeSwitchboard_,
        address owner_,
        ISocket socket_
    ) NativeSwitchboardBase(chainSlug_, owner_) {
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

    function initateNativeConfirmation(uint256 packetId) external {
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

    function receivePacket(
        uint256 packetId_,
        bytes32 root_
    ) external override onlyRemoteSwitchboard {
        roots[packetId_] = root_;
        emit RootReceived(packetId_, root_);
    }

    /**
     * @notice verifies if the packet satisfies needed checks before execution
     * @param packetId packet id
     */
    function allowPacket(
        bytes32 root,
        uint256 packetId,
        uint256,
        uint256
    ) external view override returns (bool) {
        if (tripGlobalFuse) return false;
        if (roots[packetId] != root) return false;

        return true;
    }

    function _getExecutionFees(
        uint256 msgGasLimit,
        uint256 dstRelativeGasPrice
    ) internal view override returns (uint256) {
        return (executionOverhead + msgGasLimit) * dstRelativeGasPrice;
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

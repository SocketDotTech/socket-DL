// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../../interfaces/native-bridge/IArbSys.sol";
import "../../interfaces/native-bridge/INativeReceiver.sol";

import "../../libraries/AddressAliasHelper.sol";
import "./NativeSwitchboardBase.sol";

contract ArbitrumL2Switchboard is NativeSwitchboardBase, INativeReceiver {
    address public remoteNativeSwitchboard;
    uint256 public l1ReceiveGasLimit;

    IArbSys constant arbsys = IArbSys(address(100));

    // stores the roots received from native bridge
    mapping(uint256 => bytes32) public roots;

    event UpdatedRemoteNativeSwitchboard(address remoteNativeSwitchboard_);
    event RootReceived(uint256 packetId_, bytes32 root_);
    event UpdatedL1ReceiveGasLimit(uint256 l1ReceiveGasLimit_);

    error InvalidSender();
    error NoRootFound();

    modifier onlyRemoteSwitchboard() {
        if (
            msg.sender !=
            AddressAliasHelper.applyL1ToL2Alias(remoteNativeSwitchboard)
        ) revert InvalidSender();
        _;
    }

    constructor(
        uint256 l1ReceiveGasLimit_,
        uint256 initialConfirmationGasLimit_,
        uint256 executionOverhead_,
        address remoteNativeSwitchboard_,
        address owner_,
        ISocket socket_,
        IOracle oracle_
    ) AccessControl(owner_) {
        l1ReceiveGasLimit = l1ReceiveGasLimit_;
        initateNativeConfirmationGasLimit = initialConfirmationGasLimit_;
        executionOverhead = executionOverhead_;

        remoteNativeSwitchboard = remoteNativeSwitchboard_;
        socket = socket_;
        oracle = oracle_;
    }

    function initateNativeConfirmation(uint256 packetId) external {
        bytes32 root = socket.remoteRoots(packetId);
        if (root == bytes32(0)) revert NoRootFound();

        bytes memory data = abi.encodeWithSelector(
            INativeReceiver.receivePacket.selector,
            packetId,
            root
        );

        arbsys.sendTxToL1(remoteNativeSwitchboard, data);
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

    function _getVerificationFees(
        uint256,
        uint256 dstRelativeGasPrice
    ) internal view override returns (uint256) {
        return
            initateNativeConfirmationGasLimit *
            tx.gasprice +
            l1ReceiveGasLimit *
            dstRelativeGasPrice;
    }

    function updateL2ReceiveGasLimit(
        uint256 l1ReceiveGasLimit_
    ) external onlyOwner {
        l1ReceiveGasLimit = l1ReceiveGasLimit_;
        emit UpdatedL1ReceiveGasLimit(l1ReceiveGasLimit_);
    }

    function updateRemoteNativeSwitchboard(
        address remoteNativeSwitchboard_
    ) external onlyOwner {
        remoteNativeSwitchboard = remoteNativeSwitchboard_;
        emit UpdatedRemoteNativeSwitchboard(remoteNativeSwitchboard_);
    }
}

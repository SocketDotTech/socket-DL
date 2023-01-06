// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../../interfaces/native-bridge/IInbox.sol";
import "../../interfaces/native-bridge/IOutbox.sol";
import "../../interfaces/native-bridge/IBridge.sol";
import "./NativeSwitchboardBase.sol";

contract ArbitrumL1Switchboard is NativeSwitchboardBase {
    address public remoteRefundAddress;
    address public callValueRefundAddress;
    address public remoteNativeSwitchboard;
    uint256 public dynamicFees;

    IInbox public inbox;

    // stores the roots received from native bridge
    mapping(uint256 => bytes32) public roots;

    event UpdatedInboxAddress(address inbox_);
    event UpdatedRefundAddresses(
        address remoteRefundAddress_,
        address callValueRefundAddress_
    );
    event UpdatedRemoteNativeSwitchboard(address remoteNativeSwitchboard_);
    event RootReceived(uint256 packetId_, bytes32 root_);
    event UpdatedDynamicFees(uint256 dynamicFees_);

    error InvalidSender();
    error NoRootFound();

    modifier onlyRemoteSwitchboard() {
        IBridge bridge = inbox.bridge();
        if (msg.sender != address(bridge)) revert InvalidSender();

        IOutbox outbox = IOutbox(bridge.activeOutbox());
        address l2Sender = outbox.l2ToL1Sender();
        if (l2Sender != remoteNativeSwitchboard) revert InvalidSender();

        _;
    }

    constructor(
        address remoteNativeSwitchboard_,
        address inbox_,
        address owner_,
        ISocket socket_
    ) AccessControl(owner_) {
        inbox = IInbox(inbox_);
        remoteNativeSwitchboard = remoteNativeSwitchboard_;
        socket = socket_;

        remoteRefundAddress = msg.sender;
        callValueRefundAddress = msg.sender;
    }

    function initateNativeConfirmation(
        uint256 packetId,
        uint256 maxSubmissionCost,
        uint256 maxGas,
        uint256 gasPriceBid
    ) external payable {
        bytes32 root = socket.remoteRoots(packetId);
        if (root == bytes32(0)) revert NoRootFound();

        bytes memory data = abi.encodeWithSelector(
            INativeSwitchboard.receivePacket.selector,
            packetId,
            root
        );

        // to avoid stack too deep
        address callValueRefund = callValueRefundAddress;
        address remoteRefund = remoteRefundAddress;

        inbox.createRetryableTicket{value: msg.value}(
            remoteNativeSwitchboard,
            0, // no value needed for receivePacket
            maxSubmissionCost,
            remoteRefund,
            callValueRefund,
            maxGas,
            gasPriceBid,
            data
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

    function _getVerificationFees(
        uint256 dstChainSlug,
        uint256 dstRelativeGasPrice
    ) internal view override returns (uint256) {
        // todo: check if dynamic fees can be divided into more constants
        return initateNativeConfirmationGasLimit * tx.gasprice + dynamicFees;
    }

    function updateRefundAddresses(
        address remoteRefundAddress_,
        address callValueRefundAddress_
    ) external onlyOwner {
        remoteRefundAddress = remoteRefundAddress_;
        callValueRefundAddress = callValueRefundAddress_;

        emit UpdatedRefundAddresses(
            remoteRefundAddress_,
            callValueRefundAddress_
        );
    }

    function updateDynamicFees(uint256 dynamicFees_) external onlyOwner {
        dynamicFees = dynamicFees_;
        emit UpdatedDynamicFees(dynamicFees_);
    }

    function updateInboxAddresses(address inbox_) external onlyOwner {
        inbox = IInbox(inbox_);
        emit UpdatedInboxAddress(inbox_);
    }

    function updateRemoteNativeSwitchboard(
        address remoteNativeSwitchboard_
    ) external onlyOwner {
        remoteNativeSwitchboard = remoteNativeSwitchboard_;
        emit UpdatedRemoteNativeSwitchboard(remoteNativeSwitchboard_);
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "fx-portal/tunnel/FxBaseChildTunnel.sol";
import "./NativeSwitchboardBase.sol";

contract PolygonL2Switchboard is NativeSwitchboardBase, FxBaseChildTunnel {
    // stores the roots received from native bridge
    mapping(uint256 => bytes32) public roots;
    uint256 public l2ReceiveGasLimit;

    event FxChildUpdate(address oldFxChild, address newFxChild);
    event FxRootTunnel(address fxRootTunnel, address fxRootTunnel_);
    event RootReceived(uint256 packetId_, bytes32 root_);
    event UpdatedL2ReceiveGasLimit(uint256 l2ReceiveGasLimit_);

    error NoRootFound();

    constructor(
        address fxChild_,
        address owner_,
        ISocket socket_
    ) AccessControl(owner_) FxBaseChildTunnel(fxChild_) {
        socket = socket_;
    }

    /**
     * @param packetId - packet id
     */
    function initateNativeConfirmation(uint256 packetId) external payable {
        bytes32 root = socket.remoteRoots(packetId);
        if (root == bytes32(0)) revert NoRootFound();

        bytes memory data = abi.encode(packetId, root);
        _sendMessageToRoot(data);
    }

    /**
     * validate sender verifies if `rootMessageSender` is the root contract (notary) on L1.
     */
    function _processMessageFromRoot(
        uint256,
        address rootMessageSender,
        bytes memory data
    ) internal override validateSender(rootMessageSender) {
        (uint256 packetId, bytes32 root) = abi.decode(data, (uint256, bytes32));
        roots[packetId] = root;
        emit RootReceived(packetId, root);
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
            l2ReceiveGasLimit *
            dstRelativeGasPrice;
    }

    function updateL2ReceiveGasLimit(
        uint256 l2ReceiveGasLimit_
    ) external onlyOwner {
        l2ReceiveGasLimit = l2ReceiveGasLimit_;
        emit UpdatedL2ReceiveGasLimit(l2ReceiveGasLimit_);
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
}

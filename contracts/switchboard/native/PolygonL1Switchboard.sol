// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "fx-portal/tunnel/FxBaseRootTunnel.sol";
import "./NativeSwitchboardBase.sol";

contract PolygonL1Switchboard is NativeSwitchboardBase, FxBaseRootTunnel {
    // stores the roots received from native bridge
    mapping(uint256 => bytes32) public roots;

    event FxChildTunnelSet(address fxRootTunnel, address fxRootTunnel_);
    event RootReceived(uint256 packetId_, bytes32 root_);

    error NoRootFound();

    constructor(
        uint256 initialConfirmationGasLimit_,
        uint256 executionOverhead_,
        address checkpointManager_,
        address fxRoot_,
        address owner_,
        ISocket socket_,
        IOracle oracle_
    ) AccessControl(owner_) FxBaseRootTunnel(checkpointManager_, fxRoot_) {
        socket = socket_;
        oracle = oracle_;

        initateNativeConfirmationGasLimit = initialConfirmationGasLimit_;
        executionOverhead = executionOverhead_;
    }

    /**
     * @param packetId - packet id
     */
    function initateNativeConfirmation(uint256 packetId) external payable {
        bytes32 root = socket.remoteRoots(packetId);
        if (root == bytes32(0)) revert NoRootFound();

        bytes memory data = abi.encode(packetId, root);
        _sendMessageToChild(data);
        emit InitiatedNativeConfirmation(packetId);
    }

    function _processMessageFromChild(bytes memory message) internal override {
        (uint256 packetId, bytes32 root) = abi.decode(
            message,
            (uint256, bytes32)
        );
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
        uint256
    ) internal view override returns (uint256) {
        return initateNativeConfirmationGasLimit * tx.gasprice;
    }

    // set fxChildTunnel if not set already
    function updateFxChildTunnel(address fxChildTunnel_) external onlyOwner {
        emit FxChildTunnelSet(fxChildTunnel, fxChildTunnel_);
        fxChildTunnel = fxChildTunnel_;
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "fx-portal/tunnel/FxBaseChildTunnel.sol";
import "./NativeSwitchboardBase.sol";

contract PolygonL2Switchboard is NativeSwitchboardBase, FxBaseChildTunnel {
    // stores the roots received from native bridge
    mapping(uint256 => bytes32) public roots;
    uint256 public l1ReceiveGasLimit;

    event FxChildUpdate(address oldFxChild, address newFxChild);
    event FxRootTunnelSet(address fxRootTunnel, address fxRootTunnel_);
    event RootReceived(uint256 packetId, bytes32 root);
    event UpdatedL1ReceiveGasLimit(uint256 l1ReceiveGasLimit);

    error NoRootFound();

    constructor(
        uint256 l1ReceiveGasLimit_,
        uint256 initialConfirmationGasLimit_,
        uint256 executionOverhead_,
        address fxChild_,
        address owner_,
        IOracle oracle_
    ) AccessControl(owner_) FxBaseChildTunnel(fxChild_) {
        oracle = oracle_;

        l1ReceiveGasLimit = l1ReceiveGasLimit_;
        initateNativeConfirmationGasLimit = initialConfirmationGasLimit_;
        executionOverhead = executionOverhead_;
    }

    /**
     * @param packetId - packet id
     */
    function initateNativeConfirmation(uint256 packetId) external payable {
        uint256 capacitorPacketCount = uint256(uint64(packetId));
        bytes32 root = capacitor.getRootById(capacitorPacketCount);
        if (root == bytes32(0)) revert NoRootFound();

        bytes memory data = abi.encode(packetId, root);
        _sendMessageToRoot(data);
        emit InitiatedNativeConfirmation(packetId);
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
        return roots[packetId] == root;
    }

    function _getSwitchboardFees(
        uint256,
        uint256 dstRelativeGasPrice
    ) internal view override returns (uint256) {
        return
            initateNativeConfirmationGasLimit *
            tx.gasprice +
            l1ReceiveGasLimit *
            dstRelativeGasPrice;
    }

    function updateL1ReceiveGasLimit(
        uint256 l1ReceiveGasLimit_
    ) external onlyOwner {
        l1ReceiveGasLimit = l1ReceiveGasLimit_;
        emit UpdatedL1ReceiveGasLimit(l1ReceiveGasLimit_);
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
        emit FxRootTunnelSet(fxRootTunnel, fxRootTunnel_);
        fxRootTunnel = fxRootTunnel_;
    }
}

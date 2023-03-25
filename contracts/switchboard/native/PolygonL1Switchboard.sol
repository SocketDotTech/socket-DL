// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "fx-portal/tunnel/FxBaseRootTunnel.sol";
import "./NativeSwitchboardBase.sol";
import {GOVERNANCE_ROLE} from "../../utils/AccessRoles.sol";

contract PolygonL1Switchboard is NativeSwitchboardBase, FxBaseRootTunnel {
    // stores the roots received from native bridge
    mapping(bytes32 => bytes32) public roots;

    event FxChildTunnelSet(address fxRootTunnel, address newFxRootTunnel);
    event RootReceived(bytes32 packetId, bytes32 root);

    error NoRootFound();

    constructor(
        uint256 initialConfirmationGasLimit_,
        uint256 executionOverhead_,
        address checkpointManager_,
        address fxRoot_,
        address owner_,
        IGasPriceOracle gasPriceOracle_
    ) AccessControl(owner_) FxBaseRootTunnel(checkpointManager_, fxRoot_) {
        gasPriceOracle__ = gasPriceOracle_;

        initateNativeConfirmationGasLimit = initialConfirmationGasLimit_;
        executionOverhead = executionOverhead_;
    }

    /**
     * @param packetId_ - packet id
     */
    function initateNativeConfirmation(bytes32 packetId_) external payable {
        uint64 capacitorPacketCount = uint64(uint256(packetId_));
        bytes32 root = capacitor__.getRootByCount(capacitorPacketCount);
        if (root == bytes32(0)) revert NoRootFound();

        bytes memory data = abi.encode(packetId_, root);
        _sendMessageToChild(data);
        emit InitiatedNativeConfirmation(packetId_);
    }

    function _processMessageFromChild(bytes memory message_) internal override {
        (bytes32 packetId, bytes32 root) = abi.decode(
            message_,
            (bytes32, bytes32)
        );
        roots[packetId] = root;
        emit RootReceived(packetId, root);
    }

    /**
     * @notice verifies if the packet satisfies needed checks before execution
     * @param packetId_ packet id
     */
    function allowPacket(
        bytes32 root_,
        bytes32 packetId_,
        uint32,
        uint256
    ) external view override returns (bool) {
        if (tripGlobalFuse) return false;
        if (roots[packetId_] != root_) return false;

        return true;
    }

    function _getMinSwitchboardFees(
        uint256,
        uint256,
        uint256 sourceGasPrice_
    ) internal view override returns (uint256) {
        return initateNativeConfirmationGasLimit * sourceGasPrice_;
    }

    // set fxChildTunnel if not set already
    function updateFxChildTunnel(
        address fxChildTunnel_
    ) external onlyRole(GOVERNANCE_ROLE) {
        emit FxChildTunnelSet(fxChildTunnel, fxChildTunnel_);
        fxChildTunnel = fxChildTunnel_;
    }
}

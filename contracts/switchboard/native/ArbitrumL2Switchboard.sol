// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../../interfaces/native-bridge/IArbSys.sol";
import "../../interfaces/native-bridge/INativeReceiver.sol";

import "../../libraries/AddressAliasHelper.sol";
import "./NativeSwitchboardBase.sol";
import {GOVERNANCE_ROLE, GAS_LIMIT_UPDATER_ROLE} from "../../utils/AccessRoles.sol";

contract ArbitrumL2Switchboard is NativeSwitchboardBase, INativeReceiver {
    address public remoteNativeSwitchboard;
    uint256 public l1ReceiveGasLimit;

    IArbSys public immutable arbsys__ = IArbSys(address(100));

    // stores the roots received from native bridge
    mapping(bytes32 => bytes32) public roots;

    event UpdatedRemoteNativeSwitchboard(address remoteNativeSwitchboard);
    event RootReceived(bytes32 packetId, bytes32 root);
    event UpdatedL1ReceiveGasLimit(uint256 l1ReceiveGasLimit);

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
        IGasPriceOracle gasPriceOracle_
    ) AccessControlExtended(owner_) {
        l1ReceiveGasLimit = l1ReceiveGasLimit_;
        initateNativeConfirmationGasLimit = initialConfirmationGasLimit_;
        executionOverhead = executionOverhead_;

        remoteNativeSwitchboard = remoteNativeSwitchboard_;
        gasPriceOracle__ = gasPriceOracle_;
    }

    function initateNativeConfirmation(bytes32 packetId_) external {
        uint64 capacitorPacketCount = uint64(uint256(packetId_));
        bytes32 root = capacitor__.getRootByCount(capacitorPacketCount);
        if (root == bytes32(0)) revert NoRootFound();

        bytes memory data = abi.encodeWithSelector(
            INativeReceiver.receivePacket.selector,
            packetId_,
            root
        );

        arbsys__.sendTxToL1(remoteNativeSwitchboard, data);
        emit InitiatedNativeConfirmation(packetId_);
    }

    function receivePacket(
        bytes32 packetId_,
        bytes32 root_
    ) external override onlyRemoteSwitchboard {
        roots[packetId_] = root_;
        emit RootReceived(packetId_, root_);
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
        uint256 dstRelativeGasPrice_,
        uint256 sourceGasPrice_
    ) internal view override returns (uint256) {
        return
            initateNativeConfirmationGasLimit *
            sourceGasPrice_ +
            l1ReceiveGasLimit *
            dstRelativeGasPrice_;
    }

    function updateL1ReceiveGasLimit(
        uint256 l1ReceiveGasLimit_
    ) external onlyRole(GAS_LIMIT_UPDATER_ROLE) {
        l1ReceiveGasLimit = l1ReceiveGasLimit_;
        emit UpdatedL1ReceiveGasLimit(l1ReceiveGasLimit_);
    }

    function updateRemoteNativeSwitchboard(
        address remoteNativeSwitchboard_
    ) external onlyRole(GOVERNANCE_ROLE) {
        remoteNativeSwitchboard = remoteNativeSwitchboard_;
        emit UpdatedRemoteNativeSwitchboard(remoteNativeSwitchboard_);
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../../interfaces/ISwitchboard.sol";
import "../../interfaces/IGasPriceOracle.sol";
import "../../utils/AccessControlExtended.sol";
import "../../libraries/RescueFundsLib.sol";
import "../../libraries/FeesHelper.sol";
import {TRIP_ROLE, UNTRIP_ROLE, GOVERNANCE_ROLE, GAS_LIMIT_UPDATER_ROLE, WITHDRAW_ROLE, RESCUE_ROLE} from "../../utils/AccessRoles.sol";

abstract contract SwitchboardBase is ISwitchboard, AccessControlExtended {
    IGasPriceOracle public gasPriceOracle__;

    bool public isInitialised;
    bool public tripGlobalFuse;
    uint256 public maxPacketSize;

    mapping(uint256 => uint256) public executionOverhead;

    // sourceChain => isPaused
    mapping(uint256 => bool) public tripSinglePath;

    event PathTripped(uint256 srcChainSlug, bool tripSinglePath);
    event SwitchboardTripped(bool tripGlobalFuse);
    event ExecutionOverheadSet(uint256 dstChainSlug, uint256 executionOverhead);
    event GasPriceOracleSet(address gasPriceOracle);
    event CapacitorRegistered(address capacitor, uint256 maxPacketSize);

    error TransferFailed();
    error AlreadyInitialised();

    function payFees(uint32 dstChainSlug_) external payable override {}

    function getMinFees(
        uint32 dstChainSlug_
    ) external view override returns (uint256, uint256) {
        return _calculateMinFees(dstChainSlug_);
    }

    function _calculateMinFees(
        uint32 dstChainSlug_
    ) internal view returns (uint256 switchboardFee, uint256 verificationFee) {
        uint256 dstRelativeGasPrice = gasPriceOracle__.relativeGasPrice(
            dstChainSlug_
        );

        switchboardFee = _getMinSwitchboardFees(
            dstChainSlug_,
            dstRelativeGasPrice
        );
        verificationFee =
            executionOverhead[dstChainSlug_] *
            dstRelativeGasPrice;
    }

    function _getMinSwitchboardFees(
        uint256 dstChainSlug_,
        uint256 dstRelativeGasPrice_
    ) internal view virtual returns (uint256);

    /**
     * @notice set capacitor address and packet size
     * @param capacitor_ capacitor address
     * @param maxPacketSize_ max messages allowed in one packet
     */
    function registerCapacitor(
        address capacitor_,
        uint256 maxPacketSize_
    ) external override {
        if (isInitialised) revert AlreadyInitialised();

        isInitialised = true;
        maxPacketSize = maxPacketSize_;
        emit CapacitorRegistered(capacitor_, maxPacketSize_);
    }

    /**
     * @notice pause a path
     */
    function tripPath(
        uint256 srcChainSlug_
    ) external onlyRoleWithChainSlug(TRIP_ROLE, srcChainSlug_) {
        //source chain based tripping
        tripSinglePath[srcChainSlug_] = true;
        emit PathTripped(srcChainSlug_, true);
    }

    /**
     * @notice pause execution
     */
    function tripGlobal() external onlyRole(TRIP_ROLE) {
        tripGlobalFuse = true;
        emit SwitchboardTripped(true);
    }

    /**
     * @notice unpause a path
     */
    function untripPath(
        uint256 srcChainSlug_
    ) external onlyRoleWithChainSlug(UNTRIP_ROLE, srcChainSlug_) {
        tripSinglePath[srcChainSlug_] = false;
        emit PathTripped(srcChainSlug_, false);
    }

    /**
     * @notice unpause execution
     */
    function untrip() external onlyRole(UNTRIP_ROLE) {
        tripGlobalFuse = false;
        emit SwitchboardTripped(false);
    }

    /**
     * @notice updates execution overhead
     * @param executionOverhead_ new execution overhead cost
     */
    function setExecutionOverhead(
        uint256 dstChainSlug_,
        uint256 executionOverhead_
    ) external onlyRoleWithChainSlug(GAS_LIMIT_UPDATER_ROLE, dstChainSlug_) {
        executionOverhead[dstChainSlug_] = executionOverhead_;
        emit ExecutionOverheadSet(dstChainSlug_, executionOverhead_);
    }

    /**
     * @notice updates gasPriceOracle_ address
     * @param gasPriceOracle_ new gasPriceOracle_
     */
    function setGasPriceOracle(
        address gasPriceOracle_
    ) external onlyRole(GOVERNANCE_ROLE) {
        gasPriceOracle__ = IGasPriceOracle(gasPriceOracle_);
        emit GasPriceOracleSet(gasPriceOracle_);
    }

    function withdrawFees(address account_) external onlyRole(WITHDRAW_ROLE) {
        FeesHelper.withdrawFees(account_);
    }

    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}

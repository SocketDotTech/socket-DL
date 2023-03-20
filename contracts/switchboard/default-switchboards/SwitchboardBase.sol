// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../../interfaces/ISwitchboard.sol";
import "../../interfaces/IGasPriceOracle.sol";
import "../../utils/AccessControlWithUint.sol";

import "../../libraries/RescueFundsLib.sol";

abstract contract SwitchboardBase is ISwitchboard, AccessControlWithUint {
    IGasPriceOracle public gasPriceOracle__;
    bool public tripGlobalFuse;
    mapping(uint256 => uint256) public executionOverhead;

    // sourceChain => isPaused
    mapping(uint256 => bool) public tripSinglePath;

    event PathTripped(uint256 srcChainSlug, bool tripSinglePath);
    event SwitchboardTripped(bool tripGlobalFuse);
    event ExecutionOverheadSet(uint256 dstChainSlug, uint256 executionOverhead);
    event GasPriceOracleSet(address gasPriceOracle);
    event FeesWithdrawn(address account, uint256 value);

    error TransferFailed();
    error FeesNotEnough();

    function payFees(uint256 dstChainSlug_) external payable override {
        (uint256 minExpectedFees, ) = _calculateMinFees(dstChainSlug_);
        if (msg.value < minExpectedFees) revert FeesNotEnough();
    }

    function getMinFees(
        uint256 dstChainSlug_
    ) external view override returns (uint256, uint256) {
        return _calculateMinFees(dstChainSlug_);
    }

    function _calculateMinFees(
        uint256 dstChainSlug_
    ) internal view returns (uint256 switchboardFee, uint256 verificationFee) {
        uint256 dstRelativeGasPrice = gasPriceOracle__.relativeGasPrice(
            dstChainSlug_
        );

        switchboardFee = _getSwitchboardFees(
            dstChainSlug_,
            dstRelativeGasPrice
        );
        verificationFee =
            executionOverhead[dstChainSlug_] *
            dstRelativeGasPrice;
    }

    function _getSwitchboardFees(
        uint256 dstChainSlug_,
        uint256 dstRelativeGasPrice_
    ) internal view virtual returns (uint256);

    /**
     * @notice pause a path
     */
    function tripPath(
        uint256 srcChainSlug_
    ) external onlyRoleWithUint(srcChainSlug_) {
        //source chain based tripping
        tripSinglePath[srcChainSlug_] = true;
        emit PathTripped(srcChainSlug_, true);
    }

    /**
     * @notice pause execution
     */
    function tripGlobal(
        uint256 srcChainSlug_
    ) external onlyRoleWithUint(srcChainSlug_) {
        tripGlobalFuse = true;
        emit SwitchboardTripped(true);
    }

    /**
     * @notice unpause a path
     */
    function untripPath(uint256 srcChainSlug_) external onlyOwner {
        tripSinglePath[srcChainSlug_] = false;
        emit PathTripped(srcChainSlug_, false);
    }

    /**
     * @notice unpause execution
     */
    function untrip() external onlyOwner {
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
    ) external onlyOwner {
        executionOverhead[dstChainSlug_] = executionOverhead_;
        emit ExecutionOverheadSet(dstChainSlug_, executionOverhead_);
    }

    /**
     * @notice updates gasPriceOracle_ address
     * @param gasPriceOracle_ new gasPriceOracle_
     */
    function setGasPriceOracle(address gasPriceOracle_) external onlyOwner {
        gasPriceOracle__ = IGasPriceOracle(gasPriceOracle_);
        emit GasPriceOracleSet(gasPriceOracle_);
    }

    // TODO: to support fee distribution
    /**
     * @notice transfers the fees collected to `account_`
     * @param account_ address to transfer ETH
     */
    function withdrawFees(address account_) external onlyOwner {
        require(account_ != address(0));

        uint256 value = address(this).balance;
        (bool success, ) = account_.call{value: value}("");
        if (!success) revert TransferFailed();

        emit FeesWithdrawn(account_, value);
    }

    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyOwner {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}

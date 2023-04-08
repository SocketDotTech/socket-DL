// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../../interfaces/ISwitchboard.sol";
import "../../interfaces/IGasPriceOracle.sol";
import "../../interfaces/ICapacitor.sol";

import "../../utils/AccessControlWithUint.sol";
import "../../libraries/RescueFundsLib.sol";

abstract contract NativeSwitchboardBase is ISwitchboard, AccessControlWithUint {
    IGasPriceOracle public gasPriceOracle__;
    ICapacitor public capacitor__;

    bool public tripGlobalFuse;
    uint256 public executionOverhead;
    uint256 public initateNativeConfirmationGasLimit;

    event SwitchboardTripped(bool tripGlobalFuse);
    event ExecutionOverheadSet(uint256 executionOverhead);
    event InitialConfirmationGasLimitSet(uint256 gasLimit);
    event CapacitorSet(address capacitor);
    event GasPriceOracleSet(address gasPriceOracle);
    event InitiatedNativeConfirmation(uint256 packetId);
    event FeesWithdrawn(address account, uint256 value);

    error TransferFailed();
    error FeesNotEnough();

    // assumption: natives have 18 decimals
    function payFees(uint256 dstChainSlug_) external payable override {
        (uint256 expectedFees, ) = _calculateMinFees(dstChainSlug_);
        if (msg.value < expectedFees) revert FeesNotEnough();
    }

    function getMinFees(
        uint256 dstChainSlug_
    )
        external
        view
        override
        returns (uint256 switchboardFee_, uint256 verificationFee_)
    {
        return _calculateMinFees(dstChainSlug_);
    }

    function _calculateMinFees(
        uint256 dstChainSlug_
    )
        internal
        view
        returns (uint256 switchboardFee_, uint256 verificationFee_)
    {
        (uint256 sourceGasPrice, uint256 dstRelativeGasPrice) = gasPriceOracle__
            .getGasPrices(dstChainSlug_);

        switchboardFee_ = _getMinSwitchboardFees(
            dstChainSlug_,
            dstRelativeGasPrice,
            sourceGasPrice
        );

        verificationFee_ = executionOverhead * dstRelativeGasPrice;
    }

    function _getMinSwitchboardFees(
        uint256 dstChainSlug_,
        uint256 dstRelativeGasPrice_,
        uint256 sourceGasPrice_
    ) internal view virtual returns (uint256);

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
        uint256 executionOverhead_
    ) external onlyOwner {
        executionOverhead = executionOverhead_;
        emit ExecutionOverheadSet(executionOverhead_);
    }

    /**
     * @notice updates initateNativeConfirmationGasLimit
     * @param gasLimit_ new gas limit for initiateNativeConfirmation
     */
    function setInitialConfirmationGasLimit(
        uint256 gasLimit_
    ) external onlyOwner {
        initateNativeConfirmationGasLimit = gasLimit_;
        emit InitialConfirmationGasLimitSet(gasLimit_);
    }

    /**
     * @notice updates capacitor address
     * @param capacitor_ new capacitor
     */
    function setCapacitor(address capacitor_) external onlyOwner {
        capacitor__ = ICapacitor(capacitor_);
        emit CapacitorSet(capacitor_);
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

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "./interfaces/IExecutionManager.sol";
import "./interfaces/IGasPriceOracle.sol";
import "./utils/AccessControl.sol";
import "./libraries/RescueFundsLib.sol";

contract ExecutionManager is IExecutionManager, AccessControl {
    IGasPriceOracle public gasPriceOracle__;

    // keccak256("EXECUTOR")
    bytes32 private constant _EXECUTOR_ROLE =
        0x9cf85f95575c3af1e116e3d37fd41e7f36a8a373623f51ffaaa87fdd032fa767;

    event FeesWithdrawn(address account, uint256 amount);
    error TransferFailed();

    constructor(
        IGasPriceOracle gasPriceOracle_,
        address owner_
    ) AccessControl(owner_) {
        gasPriceOracle__ = IGasPriceOracle(gasPriceOracle_);
    }

    function isExecutor(
        address executor_
    ) external view override returns (bool) {
        return _hasRole(_EXECUTOR_ROLE, executor_);
    }

    function payFees(
        uint256 msgGasLimit_,
        uint256 siblingChainSlug_
    ) external payable override {}

    function getMinFees(
        uint256 msgGasLimit_,
        uint256 siblingChainSlug_
    ) external view override returns (uint256) {
        return _getMinExecutionFees(msgGasLimit_, siblingChainSlug_);
    }

    function _getMinExecutionFees(
        uint256 msgGasLimit_,
        uint256 dstChainSlug_
    ) internal view returns (uint256) {
        uint256 dstRelativeGasPrice = gasPriceOracle__.relativeGasPrice(
            dstChainSlug_
        );
        return msgGasLimit_ * dstRelativeGasPrice;
    }

    // TODO: to support fee distribution
    /**
     * @notice transfers the fees collected to `account_`
     * @param account_ address to transfer ETH
     */
    function withdrawFees(address account_) external onlyOwner {
        require(account_ != address(0));

        uint256 amount = address(this).balance;
        (bool success, ) = account_.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FeesWithdrawn(account_, amount);
    }

    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyOwner {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}

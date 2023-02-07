// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "./interfaces/IExecutionManager.sol";
import "./interfaces/IOracle.sol";
import "./utils/AccessControl.sol";
import "./libraries/RescueFundsLib.sol";

contract ExecutionManager is IExecutionManager, AccessControl {
    IOracle public oracle;

    // keccak256("EXECUTOR")
    bytes32 private constant EXECUTOR_ROLE =
        0x9cf85f95575c3af1e116e3d37fd41e7f36a8a373623f51ffaaa87fdd032fa767;

    error TransferFailed();
    error InsufficientExecutionFees();

    constructor(IOracle oracle_, address owner_) AccessControl(owner_) {
        oracle = IOracle(oracle_);
    }

    function isExecutor(
        address executor_
    ) external view override returns (bool) {
        return _hasRole(EXECUTOR_ROLE, executor_);
    }

    function payFees(
        uint256 msgGasLimit_,
        uint256 siblingChainSlug_
    ) external payable override {
        if (msg.value < _getExecutionFees(msgGasLimit_, siblingChainSlug_))
            revert InsufficientExecutionFees();
    }

    function getMinFees(
        uint256 msgGasLimit_,
        uint256 siblingChainSlug_
    ) external view override returns (uint256) {
        return _getExecutionFees(msgGasLimit_, siblingChainSlug_);
    }

    function _getExecutionFees(
        uint256 msgGasLimit,
        uint256 dstChainSlug
    ) internal view returns (uint256) {
        uint256 dstRelativeGasPrice = oracle.relativeGasPrice(dstChainSlug);
        return msgGasLimit * dstRelativeGasPrice;
    }

    // TODO: to support fee distribution
    /**
     * @notice transfers the fees collected to `account_`
     * @param account_ address to transfer ETH
     */
    function withdrawFees(address account_) external onlyOwner {
        require(account_ != address(0));
        (bool success, ) = account_.call{value: address(this).balance}("");
        if (!success) revert TransferFailed();
    }

    function rescueFunds(
        address token,
        address userAddress,
        uint256 amount
    ) external onlyOwner {
        RescueFundsLib.rescueFunds(token, userAddress, amount);
    }
}

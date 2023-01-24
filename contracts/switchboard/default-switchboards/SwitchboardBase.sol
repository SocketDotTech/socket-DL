// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../../interfaces/ISwitchboard.sol";
import "../../interfaces/IOracle.sol";
import "../../utils/AccessControl.sol";

import "../../libraries/SafeTransferLib.sol";

abstract contract SwitchboardBase is ISwitchboard, AccessControl {
    using SafeTransferLib for IERC20;

    IOracle public oracle;
    bool public tripGlobalFuse;
    mapping(uint256 => uint256) public executionOverhead;

    event SwitchboardTripped(bool tripGlobalFuse_);
    event ExecutionOverheadSet(
        uint256 dstChainSlug_,
        uint256 executionOverhead_
    );
    event OracleSet(address oracle_);

    error TransferFailed();
    error FeesNotEnough();

    function payFees(uint256 dstChainSlug) external payable override {
        uint256 expectedFees = _calculateFees(dstChainSlug);
        if (msg.value < expectedFees) revert FeesNotEnough();
    }

    function getMinFees(
        uint256 dstChainSlug
    ) external view override returns (uint256) {
        return _calculateFees(dstChainSlug);
    }

    function _calculateFees(
        uint256 dstChainSlug
    ) internal view returns (uint256 expectedFees) {
        uint256 dstRelativeGasPrice = oracle.relativeGasPrice(dstChainSlug);

        uint256 minVerificationFees = _getVerificationFees(
            dstChainSlug,
            dstRelativeGasPrice
        );

        expectedFees =
            executionOverhead[dstChainSlug] *
            dstRelativeGasPrice +
            minVerificationFees;
    }

    function _getVerificationFees(
        uint256 dstChainSlug,
        uint256 dstRelativeGasPrice
    ) internal view virtual returns (uint256) {}

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
     * @notice updates oracle address
     * @param oracle_ new oracle
     */
    function setOracle(address oracle_) external onlyOwner {
        oracle = IOracle(oracle_);
        emit OracleSet(oracle_);
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
        if (token == address(0)) {
            payable(userAddress).transfer(amount);
        } else {
            // do we need safe transfer?
            IERC20(token).transfer(userAddress, amount);
        }
    }
}

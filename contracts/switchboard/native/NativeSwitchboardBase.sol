// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../../interfaces/ISwitchboard.sol";
import "../../interfaces/IOracle.sol";
import "../../utils/AccessControl.sol";
import "../../interfaces/ISocket.sol";
import "../../libraries/SafeTransferLib.sol";

abstract contract NativeSwitchboardBase is ISwitchboard, AccessControl {
    IOracle public oracle;
    ISocket public socket;

    bool public tripGlobalFuse;
    uint256 public executionOverhead;
    uint256 public initateNativeConfirmationGasLimit;

    event SwitchboardTripped(bool tripGlobalFuse_);
    event ExecutionOverheadSet(uint256 executionOverhead_);
    event InitialConfirmationGasLimitSet(uint256 gasLimit_);
    event OracleSet(address oracle_);
    event SocketSet(address socket);

    error TransferFailed();
    error FeesNotEnough();

    // assumption: natives have 18 decimals
    function payFees(uint256 dstChainSlug) external payable override {
        (uint256 expectedFees, ) = _calculateFees(dstChainSlug);
        if (msg.value < expectedFees) revert FeesNotEnough();
    }

    function getMinFees(
        uint256 dstChainSlug
    )
        external
        view
        override
        returns (uint256 switchboardFee, uint256 executionFee)
    {
        return _calculateFees(dstChainSlug);
    }

    function _calculateFees(
        uint256 dstChainSlug
    ) internal view returns (uint256 switchboardFee, uint256 executionFee) {
        uint256 dstRelativeGasPrice = oracle.relativeGasPrice(dstChainSlug);

        switchboardFee = _getSwitchboardFees(dstChainSlug, dstRelativeGasPrice);

        executionFee = executionOverhead * dstRelativeGasPrice;
    }

    function _getSwitchboardFees(
        uint256 dstChainSlug,
        uint256 dstRelativeGasPrice
    ) internal view virtual returns (uint256) {}

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
     * @notice updates oracle address
     * @param oracle_ new oracle
     */
    function setOracle(address oracle_) external onlyOwner {
        oracle = IOracle(oracle_);
        emit OracleSet(oracle_);
    }

    function setSocket(address socket_) external onlyOwner {
        socket = ISocket(socket_);
        emit SocketSet(socket_);
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

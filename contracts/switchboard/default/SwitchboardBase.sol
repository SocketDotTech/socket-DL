// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../../interfaces/ISwitchboard.sol";
import "../../interfaces/IOracle.sol";
import "../../utils/AccessControl.sol";

abstract contract SwitchboardBase is ISwitchboard, AccessControl {
    IOracle public oracle;
    bool public tripGlobalFuse;
    uint256 public immutable chainSlug;
    mapping(uint256 => uint256) public executionOverhead;

    event SwitchboardTripped(bool tripGlobalFuse_);
    event ExecutionOverheadSet(
        uint256 dstChainSlug_,
        uint256 executionOverhead_
    );

    error TransferFailed();
    error FeesNotEnough();

    constructor(uint32 chainSlug_, address owner_) AccessControl(owner_) {
        chainSlug = chainSlug_;
    }

    // assumption: natives have 18 decimals
    function payFees(
        uint256 msgGasLimit,
        uint256 dstChainSlug
    ) external payable override {
        uint256 dstRelativeGasPrice = oracle.relativeGasPrice(dstChainSlug);

        uint256 minExecutionFees = _getExecutionFees(
            msgGasLimit,
            dstChainSlug,
            dstRelativeGasPrice
        );
        uint256 minVerificationFees = _getVerificationFees(
            dstChainSlug,
            dstRelativeGasPrice
        );

        uint256 expectedFees = minExecutionFees + minVerificationFees;
        if (msg.value <= expectedFees) revert FeesNotEnough();
    }

    // overridden in child contracts
    function _getExecutionFees(
        uint256 msgGasLimit,
        uint256 dstChainSlug,
        uint256 dstRelativeGasPrice
    ) internal view virtual returns (uint256) {}

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
}

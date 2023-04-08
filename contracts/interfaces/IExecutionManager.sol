// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

interface IExecutionManager {
    function isExecutor(
        bytes32 packedMessage,
        bytes memory sig
    ) external view returns (address, bool);

    function payFees(uint256 msgGasLimit, uint256 dstSlug) external payable;

    function getMinFees(
        uint256 msgGasLimit,
        uint256 dstSlug
    ) external view returns (uint256);
}

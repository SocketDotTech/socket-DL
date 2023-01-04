// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

interface IOracle {
    function relativeGasPrice(
        uint256 dstChainSlug
    ) external view returns (uint256);
}

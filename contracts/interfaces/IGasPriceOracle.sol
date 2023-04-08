// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

interface IGasPriceOracle {
    function relativeGasPrice(
        uint32 dstChainSlug
    ) external view returns (uint256);

    function sourceGasPrice() external view returns (uint256);

    function getGasPrices(
        uint32 dstChainSlug_
    ) external view returns (uint256, uint256);
}

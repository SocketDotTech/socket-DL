// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

/**
 * @title IGasPriceOracle
 * @notice Interface for a gas price oracle contract that provides the gas prices for different chains.
 * @dev The gas prices are provided in wei.
 * @dev The oracle can provide a relative gas price for a specific destination chain, as well as the source gas price on the oracle chain.
 */
interface IGasPriceOracle {
    /*
     * @notice Returns the relative gas price for a destination chain.
     * @param dstChainSlug The identifier of the destination chain.
     * @return The relative gas price for the destination chain in wei.
     */
    function relativeGasPrice(
        uint32 dstChainSlug
    ) external view returns (uint256);

    /**
     * @notice Returns the source gas price on the oracle chain.
     * @return The source gas price on the oracle chain in wei.
     */
    function sourceGasPrice() external view returns (uint256);

    /**
     * @notice Returns the gas prices for a destination chain.
     * @param dstChainSlug_ The identifier of the destination chain.
     * @return The relative gas price for the destination chain in wei.
     * @return The source gas price on the oracle chain in wei.
     */
    function getGasPrices(
        uint32 dstChainSlug_
    ) external view returns (uint256, uint256);
}

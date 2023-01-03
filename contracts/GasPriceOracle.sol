// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./interfaces/IOracle.sol";
import "./interfaces/ITransmitManager.sol";
import "./utils/AccessControl.sol";

contract GasPriceOracle is IOracle {
    // Native token <> USD price feed oracle address
    IAggregatorV3Interface public priceFeed;
    ITransmitManager public transmitManager;

    mapping(uint256 => uint256) public dstGasPrice;
    mapping(uint256 => uint256) public dstGasUSDPrice;

    uint256 public PRICE_PRECISION = 10 ** 6;

    // plugs/switchboards/transmitter can use it to ensure prices are updated
    mapping(uint256 => uint256) public updatedAt;
    event PriceUpdated(
        uint256 dstChainSlug_,
        uint256 dstGasPrice_,
        uint256 dstGasUSDPrice_
    );

    error TransmitterNotFound();
    error InvalidPrecision();

    constructor(
        IAggregatorV3Interface priceFeed_,
        ITransmitManager transmitManager_
    ) {
        priceFeed = priceFeed_;
        transmitManager = transmitManager_;
    }

    // value returned will have precision same as dst native token
    function getRelativeGasPrice(
        uint256 dstChainSlug
    ) external view override returns (uint256) {
        return
            (dstGasPrice[dstChainSlug] *
                dstGasUSDPrice[dstChainSlug] *
                10 ** priceFeed.decimals()) / (srcUsdPrice() * PRICE_PRECISION);
    }

    function setPrices(
        uint256 dstChainSlug_,
        uint256 dstGasPrice_,
        uint256 dstGasUSDPrice_
    ) external {
        if (!transmitManager.isTransmitter(msg.sender))
            revert TransmitterNotFound();
        if (dstGasUSDPrice_ >= PRICE_PRECISION) revert InvalidPrecision();

        dstGasPrice[dstChainSlug_] = dstGasPrice_;
        dstGasUSDPrice[dstChainSlug_] = dstGasUSDPrice_;
        updatedAt[dstChainSlug_] = block.timestamp;

        emit PriceUpdated(dstChainSlug_, dstGasPrice_, dstGasUSDPrice_);
    }

    function srcUsdPrice() internal view returns (uint256) {
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        return uint256(answer);
    }
}

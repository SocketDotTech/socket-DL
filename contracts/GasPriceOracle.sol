// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./interfaces/IOracle.sol";
import "./utils/AccessControl.sol";

interface IAggregatorV3Interface {
    function decimals() external view returns (uint8);

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract GasPriceOracle is IOracle, AccessControl(msg.sender) {
    // Native token <> USD price feed oracle address
    IAggregatorV3Interface public priceFeed;

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

    constructor(IAggregatorV3Interface priceFeed_) {
        priceFeed = priceFeed_;
    }

    // value returned will have PRICE_PRECISION.
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
        if (!_hasRole(_transmitterRole(dstChainSlug_), msg.sender))
            revert TransmitterNotFound();

        if (
            dstGasPrice_ >= PRICE_PRECISION ||
            dstGasUSDPrice_ >= PRICE_PRECISION
        ) revert InvalidPrecision();

        dstGasPrice[dstChainSlug_] = dstGasPrice_;
        dstGasUSDPrice[dstChainSlug_] = dstGasUSDPrice_;
        updatedAt[dstChainSlug_] = block.timestamp;

        emit PriceUpdated(dstChainSlug_, dstGasPrice_, dstGasUSDPrice_);
    }

    function srcUsdPrice() internal view returns (uint256) {
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        return uint256(answer);
    }

    /**
     * @notice adds a transmitter for `remoteChainSlug_` chain
     * @param remoteChainSlug_ remote chain slug
     * @param transmitter_ transmitter address
     */
    function grantTransmitterRole(
        uint256 remoteChainSlug_,
        address transmitter_
    ) external onlyOwner {
        _grantRole(_transmitterRole(remoteChainSlug_), transmitter_);
    }

    /**
     * @notice removes an transmitter from `remoteChainSlug_` chain list
     * @param remoteChainSlug_ remote chain slug
     * @param transmitter_ transmitter address
     */
    function revokeTransmitterRole(
        uint256 remoteChainSlug_,
        address transmitter_
    ) external onlyOwner {
        _revokeRole(_transmitterRole(remoteChainSlug_), transmitter_);
    }

    function _transmitterRole(
        uint256 chainSlug_
    ) internal pure returns (bytes32) {
        return bytes32(chainSlug_);
    }
}

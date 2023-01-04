// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./interfaces/IOracle.sol";
import "./utils/AccessControl.sol";

interface ITransmitManager {
    function isTransmitter(
        address transmitter_,
        uint256 dstChainSlug_
    ) external view returns (bool);
}

contract GasPriceOracle is IOracle {
    ITransmitManager public transmitManager;

    // plugs/switchboards/transmitter can use it to ensure prices are updated
    mapping(uint256 => uint256) public updatedAt;
    // chain slug => relative gas price
    mapping(uint256 => uint256) public override relativeGasPrice;

    event GasPriceUpdated(uint256 dstChainSlug_, uint256 relativeGasPrice_);

    error TransmitterNotFound();
    error InvalidPrecision();

    constructor(ITransmitManager transmitManager_) {
        transmitManager = transmitManager_;
    }

    /**
     * @dev the relative prices are calculated as:
     * relativeGasPrice = (dstGasPrice * dstGasUSDPrice)/srcGasUSDPrice
     * It is assumed that precision of relative gas price will be same as src native tokens
     * So that when it is multiplied with gas limits at other contracts, we get correct values.
     */
    function setRelativeGasPrice(
        uint256 dstChainSlug_,
        uint256 relativeGasPrice_
    ) external {
        if (!transmitManager.isTransmitter(msg.sender, dstChainSlug_))
            revert TransmitterNotFound();

        relativeGasPrice[dstChainSlug_] = relativeGasPrice_;
        updatedAt[dstChainSlug_] = block.timestamp;

        emit GasPriceUpdated(dstChainSlug_, relativeGasPrice_);
    }
}

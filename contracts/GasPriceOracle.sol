// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./interfaces/IOracle.sol";
import "./interfaces/ITransmitManager.sol";
import "./utils/AccessControl.sol";
import "./libraries/SafeTransferLib.sol";

contract GasPriceOracle is IOracle, Ownable {
    using SafeTransferLib for IERC20;

    // plugs/switchboards/transmitter can use it to ensure prices are updated
    mapping(uint256 => uint256) public updatedAt;
    // chain slug => relative gas price
    mapping(uint256 => uint256) public override relativeGasPrice;

    event GasPriceUpdated(uint256 dstChainSlug_, uint256 relativeGasPrice_);

    constructor(address owner_) Ownable(owner_) {}

    /**
     * @dev the relative prices are calculated as:
     * relativeGasPrice = (dstGasPrice * dstGasUSDPrice)/srcGasUSDPrice
     * It is assumed that precision of relative gas price will be same as src native tokens
     * So that when it is multiplied with gas limits at other contracts, we get correct values.
     */
    function setRelativeGasPrice(
        uint256 dstChainSlug_,
        uint256 relativeGasPrice_
    ) public onlyOwner() {
        relativeGasPrice[dstChainSlug_] = relativeGasPrice_;
        updatedAt[dstChainSlug_] = block.timestamp;

        emit GasPriceUpdated(dstChainSlug_, relativeGasPrice_);
    }

    /**
     * @dev the relative prices are calculated as:
     * relativeGasPrice = (dstGasPrice * dstGasUSDPrice)/srcGasUSDPrice
     * It is assumed that precision of relative gas price will be same as src native tokens
     * So that when it is multiplied with gas limits at other contracts, we get correct values.
     */
    function bulkSetRelativeGasPrice(
        uint256[] calldata dstChainSlug_,
        uint256[] calldata relativeGasPrice_
    ) public onlyOwner() {
        require(dstChainSlug_.length == relativeGasPrice_.length, "GasPriceOracle: invalid input");
        for (uint256 i = 0; i < dstChainSlug_.length; i++) {  
            setRelativeGasPrice(dstChainSlug_[i], relativeGasPrice_[i]);
        }
    }

    // 
    // RESCUE FUNCTIONS
    // 
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

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../utils/Ownable.sol";
import "../interfaces/IVault.sol";

contract Vault is IVault, Ownable {
    // config index from socket => fees
    mapping(uint256 => uint256) public minFees;
    error NotEnoughFees();

    constructor(address owner_) Ownable(owner_) {}

    /// @inheritdoc IVault
    function deductFee(uint256, uint256 configId_) external payable override {
        if (msg.value < minFees[configId_]) revert NotEnoughFees();

        emit FeeDeducted(msg.value);
    }

    /// @inheritdoc IVault
    function claimFee(address account_, uint256 amount_)
        external
        override
        onlyOwner
    {
        (bool success, ) = account_.call{value: amount_}("");
        require(success, "Transfer failed.");
    }

    /// @inheritdoc IVault
    function getFees(uint256 remoteChainId_, uint256 configId_)
        external
        pure
        override
        returns (uint256)
    {
        return minFees[configId_];
    }

    /// @inheritdoc IVault
    function setFees(uint256 minFees_, uint256 configId_)
        external
        override
        onlyOwner
        returns (uint256)
    {
        minFees[configId_] = minFees_;
        emit FeesSet(minFees_, configId_);
    }
}

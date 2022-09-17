// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../utils/Ownable.sol";
import "../interfaces/IVault.sol";
import "../Version0.sol";

contract Vault is IVault, Ownable, Version0 {
    constructor(address owner_) Ownable(owner_) {}

    /// @inheritdoc IVault
    function deductFee(uint256, uint256) external payable override {
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
    function getFees(uint256, uint256)
        external
        pure
        override
        returns (uint256)
    {
        return 0;
    }
}

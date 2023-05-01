// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

/**
 * @title FeesHelper
 * @dev A library for managing fee collection and distribution.
 * @dev This contract will be further developed to support fee distribution to various
 * participants of the system
 */
library FeesHelper {
    error TransferFailed();
    event FeesWithdrawn(address account, uint256 amount);

    /**
     * @dev Transfers the fees collected to the specified address.
     * @notice The caller of this function must have the required funds.
     * @param account_ The address to transfer ETH to.
     */
    function withdrawFees(address account_) internal {
        require(account_ != address(0));

        uint256 amount = address(this).balance;
        (bool success, ) = account_.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FeesWithdrawn(account_, amount);
    }
}

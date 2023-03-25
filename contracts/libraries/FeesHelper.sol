// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

library FeesHelper {
    error TransferFailed();
    event FeesWithdrawn(address account, uint256 amount);

    // TODO: to support fee distribution
    /**
     * @notice transfers the fees collected to `account_`
     * @param account_ address to transfer ETH
     */
    function withdrawFees(address account_) internal {
        require(account_ != address(0));

        uint256 amount = address(this).balance;
        (bool success, ) = account_.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FeesWithdrawn(account_, amount);
    }
}

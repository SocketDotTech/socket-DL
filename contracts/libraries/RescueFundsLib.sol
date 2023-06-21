// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.20;

import "solmate/utils/SafeTransferLib.sol";

/**
 * @title RescueFundsLib
 * @dev A library that provides a function to rescue funds from a contract.
 */
library RescueFundsLib {
    /**
     * @dev The address used to identify ETH.
     */
    address public constant ETH_ADDRESS =
        address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    /**
     * @dev thrown when the given token address don't have any code
     */
    error InvalidTokenAddress();

    /**
     * @dev Rescues funds from a contract.
     * @param token_ The address of the token contract.
     * @param userAddress_ The address of the user.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) internal {
        require(userAddress_ != address(0));

        if (token_ == ETH_ADDRESS) {
            (bool success, ) = userAddress_.call{value: amount_}("");
            require(success);
        } else {
            if (token_.code.length == 0) revert InvalidTokenAddress();
            SafeTransferLib.safeTransfer(ERC20(token_), userAddress_, amount_);
        }
    }
}

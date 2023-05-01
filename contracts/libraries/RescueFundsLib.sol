// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./SafeTransferLib.sol";

/**
 * @title RescueFundsLib
 * @dev A library that provides a function to rescue funds from a contract that has lost access to them.
 */
library RescueFundsLib {
    using SafeTransferLib for IERC20;

    /**
     * @dev The address used to identify ETH.
     */
    address public constant ETH_ADDRESS =
        address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    /**
     * @dev Rescues funds from a contract that has lost access to them.
     * @param token_ The address of the token contract.
     * @param userAddress_ The address of the user who lost access to the funds.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) internal {
        require(userAddress_ != address(0));

        if (token_ == ETH_ADDRESS) {
            (bool success, ) = userAddress_.call{value: address(this).balance}(
                ""
            );
            require(success);
        } else {
            IERC20(token_).transfer(userAddress_, amount_);
        }
    }
}

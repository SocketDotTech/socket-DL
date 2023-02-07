// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../libraries/SafeTransferLib.sol";

library RescueFundsLib {
    using SafeTransferLib for IERC20;
    address public constant ETH_ADDRESS =
        address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    function rescueFunds(
        address token,
        address userAddress,
        uint256 amount
    ) internal {
        require(userAddress != address(0));

        if (token == ETH_ADDRESS) {
            (bool success, ) = userAddress.call{value: address(this).balance}(
                ""
            );
            require(success);
        } else {
            IERC20(token).transfer(userAddress, amount);
        }
    }
}

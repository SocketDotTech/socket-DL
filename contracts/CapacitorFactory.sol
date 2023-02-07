// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./interfaces/ICapacitorFactory.sol";
import "./capacitors/SingleCapacitor.sol";
import "./capacitors/HashChainCapacitor.sol";
import "./decapacitors/SingleDecapacitor.sol";
import "./decapacitors/HashChainDecapacitor.sol";
import "./libraries/RescueFundsLib.sol";
import "./utils/Ownable.sol";

contract CapacitorFactory is ICapacitorFactory, Ownable(msg.sender) {
    function deploy(
        uint256 capacitorType,
        uint256 /** siblingChainSlug */
    ) external override returns (ICapacitor, IDecapacitor) {
        if (capacitorType == 1) {
            return (new SingleCapacitor(msg.sender), new SingleDecapacitor());
        }
        if (capacitorType == 2) {
            return (
                new HashChainCapacitor(msg.sender),
                new HashChainDecapacitor()
            );
        }
        revert InvalidCapacitorType();
    }

    function rescueFunds(
        address token,
        address userAddress,
        uint256 amount
    ) external onlyOwner {
        RescueFundsLib.rescueFunds(token, userAddress, amount);
    }
}

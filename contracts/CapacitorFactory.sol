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
    uint256 private constant SINGLE_CAPACITOR = 1;
    uint256 private constant HASH_CHAIN_CAPACITOR = 2;

    function deploy(
        uint256 capacitorType_,
        uint256 /** siblingChainSlug */
    ) external override returns (ICapacitor, IDecapacitor) {
        if (capacitorType_ == SINGLE_CAPACITOR) {
        }
        if (capacitorType_ == HASH_CHAIN_CAPACITOR) {
            return (
                new HashChainCapacitor(msg.sender),
                new HashChainDecapacitor()
            );
        }
        revert InvalidCapacitorType();
    }

    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyOwner {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}

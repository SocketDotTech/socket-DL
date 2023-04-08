// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./interfaces/ICapacitorFactory.sol";
import "./capacitors/SingleCapacitor.sol";
import "./capacitors/HashChainCapacitor.sol";
import "./decapacitors/SingleDecapacitor.sol";
import "./decapacitors/HashChainDecapacitor.sol";

import "./libraries/RescueFundsLib.sol";
import "./utils/AccessControlExtended.sol";
import {RESCUE_ROLE} from "./utils/AccessRoles.sol";

contract CapacitorFactory is ICapacitorFactory, AccessControlExtended {
    uint256 private constant SINGLE_CAPACITOR = 1;
    uint256 private constant HASH_CHAIN_CAPACITOR = 2;

    constructor(address owner_) AccessControlExtended(owner_) {}

    function deploy(
        uint256 capacitorType_,
        uint256 /** siblingChainSlug */,
        uint256 /** maxPacketLength */
    ) external override returns (ICapacitor, IDecapacitor) {
        address owner = this.owner();

        if (capacitorType_ == SINGLE_CAPACITOR) {
            return (
                new SingleCapacitor(msg.sender, owner),
                new SingleDecapacitor(owner)
            );
        }
        if (capacitorType_ == HASH_CHAIN_CAPACITOR) {
            return (
                new HashChainCapacitor(msg.sender, owner),
                new HashChainDecapacitor(owner)
            );
        }
        revert InvalidCapacitorType();
    }

    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}

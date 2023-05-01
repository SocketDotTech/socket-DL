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

/**
 * @title CapacitorFactory
 * @notice Factory contract for creating capacitor and decapacitor pairs of different types.
 * @dev This contract is modular and can be updated in Socket with more capacitor types.
 * @dev The capacitorType_ parameter determines the type of capacitor and decapacitor to deploy.
 */
contract CapacitorFactory is ICapacitorFactory, AccessControlExtended {
    uint256 private constant SINGLE_CAPACITOR = 1;
    uint256 private constant HASH_CHAIN_CAPACITOR = 2;

    /**
     * @notice initialises and grants RESCUE_ROLE to owner.
     * @param owner_ The address of the owner of the contract.
     */
    constructor(address owner_) AccessControlExtended(owner_) {
        _grantRole(RESCUE_ROLE, owner_);
    }

    /**
     * @notice Creates a new capacitor and decapacitor pair based on the given type.
     * @dev It sets the capacitor factory owner as capacitor and decapacitor's owner.
     * @dev maxPacketLength is not being used with single capacitor system, will be useful later with batching
     * @dev siblingChainSlug sibling chain slug can be used for chain specific capacitors
     * @param capacitorType_ The type of capacitor to be created. Can be SINGLE_CAPACITOR or HASH_CHAIN_CAPACITOR.
     */
    function deploy(
        uint256 capacitorType_,
        uint256 /** siblingChainSlug */,
        uint256 /** maxPacketLength */
    ) external override returns (ICapacitor, IDecapacitor) {
        // sets the capacitor factory owner
        address owner = this.owner();

        if (capacitorType_ == SINGLE_CAPACITOR) {
            return (
                // msg.sender is socket address
                new SingleCapacitor(msg.sender, owner),
                new SingleDecapacitor(owner)
            );
        }
        if (capacitorType_ == HASH_CHAIN_CAPACITOR) {
            return (
                // msg.sender is socket address
                new HashChainCapacitor(msg.sender, owner),
                new HashChainDecapacitor(owner)
            );
        }
        revert InvalidCapacitorType();
    }

    /**
     * @notice Rescues funds from a contract that has lost access to them.
     * @param token_ The address of the token contract.
     * @param userAddress_ The address of the user who lost access to the funds.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}

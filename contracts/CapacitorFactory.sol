// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "./interfaces/ICapacitorFactory.sol";
import "./capacitors/SingleCapacitor.sol";
import "./capacitors/HashChainCapacitor.sol";
import "./decapacitors/SingleDecapacitor.sol";
import "./decapacitors/HashChainDecapacitor.sol";

import "./libraries/RescueFundsLib.sol";
import "./utils/AccessControl.sol";
import {RESCUE_ROLE} from "./utils/AccessRoles.sol";

/**
 * @title CapacitorFactory
 * @notice Factory contract for creating capacitor and decapacitor pairs.
 * @dev The capacitorType_ parameter determines the type of capacitor and decapacitor to deploy.
 * @dev More types can be introduced by deploying new contract and pointing to it on Socket.
 */
contract CapacitorFactory is ICapacitorFactory, AccessControl {
    uint256 private constant SINGLE_CAPACITOR = 1;
    uint256 private constant HASH_CHAIN_CAPACITOR = 2;

    /**
     * @notice initializes and grants RESCUE_ROLE to owner.
     * @param owner_ The address of the owner of the contract.
     */
    constructor(address owner_) AccessControl(owner_) {
        _grantRole(RESCUE_ROLE, owner_);
    }

    /**
     * @notice Creates a new capacitor and decapacitor pair based on the given type.
     * @dev It sets the CapacitorFactory owner as owner of new Capacitor and Decapacitor
     * @param capacitorType_ The type of capacitor to be created. Can be SINGLE_CAPACITOR or HASH_CHAIN_CAPACITOR.
     * @dev siblingChainSlug_ sibling chain slug can be used for chain specific capacitors, useful while expanding to non-EVM chains.
     * @param maxPacketLength_ is not being used with single capacitor system, will be useful with batching.
     */
    function deploy(
        uint256 capacitorType_,
        uint32 /** siblingChainSlug_ */,
        uint256 maxPacketLength_
    ) external override returns (ICapacitor, IDecapacitor) {
        // fetch the capacitor factory owner
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
                new HashChainCapacitor(msg.sender, owner, maxPacketLength_),
                new HashChainDecapacitor(owner)
            );
        }
        revert InvalidCapacitorType();
    }

    /**
     * @notice Rescues funds from the contract if they are locked by mistake.
     * @param token_ The address of the token contract.
     * @param rescueTo_ The address where rescued tokens need to be sent.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(
        address token_,
        address rescueTo_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, rescueTo_, amount_);
    }
}

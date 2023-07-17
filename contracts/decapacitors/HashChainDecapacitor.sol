// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../interfaces/IDecapacitor.sol";
import "../libraries/RescueFundsLib.sol";
import "../utils/AccessControl.sol";
import {RESCUE_ROLE} from "../utils/AccessRoles.sol";

/**
 * @title HashChainDecapacitor
 * @notice  This is an experimental contract and have known bugs
 * @notice A contract that verifies whether a message is part of a hash chain or not.
 * @dev This contract implements the `IDecapacitor` interface.
 */
contract HashChainDecapacitor is IDecapacitor, AccessControl {
    /**
     * @notice Initializes the HashChainDecapacitor contract with the owner's address.
     * @param owner_ The address of the contract owner.
     */
    constructor(address owner_) AccessControl(owner_) {
        _grantRole(RESCUE_ROLE, owner_);
    }

    /**
     * @notice Verifies whether a message is included in the given hash chain.
     * @param root_ The root of the hash chain.
     * @param packedMessage_ The packed message whose inclusion in the hash chain needs to be verified.
     * @param proof_ The proof for the inclusion of the packed message in the hash chain.
     * @return True if the packed message is included in the hash chain and the provided root is the calculated root; otherwise, false.
     */
    function verifyMessageInclusion(
        bytes32 root_,
        bytes32 packedMessage_,
        bytes calldata proof_
    ) external pure override returns (bool) {
        bytes32[] memory chain = abi.decode(proof_, (bytes32[]));
        uint256 len = chain.length;
        bytes32 generatedRoot;
        bool isIncluded;
        for (uint256 i = 0; i < len; ) {
            generatedRoot = keccak256(abi.encode(generatedRoot, chain[i]));
            if (chain[i] == packedMessage_) isIncluded = true;
            unchecked {
                ++i;
            }
        }

        return root_ == generatedRoot && isIncluded;
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

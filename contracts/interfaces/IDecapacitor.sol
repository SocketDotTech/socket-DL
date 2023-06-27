// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

/**
 * @title IDecapacitor interface
 * @notice Interface for a contract that verifies if a packed message is part of a packet or not
 */
interface IDecapacitor {
    /**
     * @notice returns if the packed message is the part of a packet or not
     * @dev this function can be used to update deCapacitor states as well
     * @param root_ root hash of the packet
     * @param packedMessage_ packed message which needs to be verified
     * @param proof_ proof used to determine the inclusion
     * @dev this function is kept as view instead of pure, as in future we may have stateful decapacitors
     */
    function verifyMessageInclusion(
        bytes32 root_,
        bytes32 packedMessage_,
        bytes calldata proof_
    ) external returns (bool);
}

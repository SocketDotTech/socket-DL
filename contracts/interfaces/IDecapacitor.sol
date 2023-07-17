// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

/**
 * @title IDecapacitor interface
 * @notice Interface for a contract that verifies if a packed message is part of a packet or not
 */
interface IDecapacitor {
    /**
     * @notice Returns true if packed message is part of root.
     * @param root_ root hash of the packet.
     * @param packedMessage_ packed message which needs to be verified.
     * @param proof_ proof used to determine the inclusion
     * @dev This function is kept as view instead of pure, as in future we may have stateful decapacitors
     * @return isIncluded boolean indicating whether the message is included in the packet or not.
     */
    function verifyMessageInclusion(
        bytes32 root_,
        bytes32 packedMessage_,
        bytes calldata proof_
    ) external returns (bool isIncluded);
}

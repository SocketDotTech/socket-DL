// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.20;

import "./SwitchboardBase.sol";

/**
 * @title OptimisticSwitchboard
 * @notice A contract that extends the SwitchboardBase contract and implements the
 * allowPacket and fee getter functions.
 */
contract OptimisticSwitchboard is SwitchboardBase {
    /**
     * @notice Creates an OptimisticSwitchboard instance with the specified parameters.
     * @param owner_ The address of the contract owner.
     * @param socket_ The address of the socket contract.
     * @param chainSlug_ The chain slug.
     * @param timeoutInSeconds_ The timeout period in seconds.
     * @param signatureVerifier_ The address of the signature verifier contract
     */
    constructor(
        address owner_,
        address socket_,
        uint32 chainSlug_,
        uint256 timeoutInSeconds_,
        ISignatureVerifier signatureVerifier_
    )
        AccessControlExtended(owner_)
        SwitchboardBase(
            socket_,
            chainSlug_,
            timeoutInSeconds_,
            signatureVerifier_
        )
    {}

    /**
     * @inheritdoc ISwitchboard
     */
    function allowPacket(
        bytes32,
        bytes32 packetId_,
        uint256 proposalCount_,
        uint32 srcChainSlug_,
        uint256 proposeTime_
    ) external view override returns (bool) {
        uint64 packetCount = uint64(uint256(packetId_));

        if (
            tripGlobalFuse ||
            tripSinglePath[srcChainSlug_] ||
            isProposalTripped[packetId_][proposalCount_] ||
            packetCount < initialPacketCount[srcChainSlug_]
        ) return false;
        if (block.timestamp - proposeTime_ < timeoutInSeconds) return false;
        return true;
    }
}

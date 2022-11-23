// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IVerifier.sol";
import "../interfaces/INotary.sol";

import "../utils/Ownable.sol";

contract Verifier is IVerifier, Ownable {
    INotary public notary;
    uint256 public immutable timeoutInSeconds;

    // this integration type is set for fast accum
    // it is compared against the passed accum type to decide packet verification mode
    bytes32 public immutable fastIntegrationType;

    event NotarySet(address notary_);

    constructor(
        address owner_,
        address notary_,
        uint256 timeoutInSeconds_,
        bytes32 fastIntegrationType_
    ) Ownable(owner_) {
        notary = INotary(notary_);
        fastIntegrationType = fastIntegrationType_;

        // TODO: restrict the timeout durations to a few select options
        timeoutInSeconds = timeoutInSeconds_;
    }

    /**
     * @notice updates notary
     * @param notary_ address of Notary
     */
    function setNotary(address notary_) external onlyOwner {
        notary = INotary(notary_);
        emit NotarySet(notary_);
    }

    /**
     * @notice verifies if the packet satisfies needed checks before execution
     * @param packetId_ packet id
     * @param fastIntegrationType_ integration type for plug
     */
    function verifyPacket(uint256 packetId_, bytes32 fastIntegrationType_)
        external
        view
        override
        returns (bool, bytes32)
    {
        bool isFast = fastIntegrationType == fastIntegrationType_
            ? true
            : false;

        (
            INotary.PacketStatus status,
            uint256 packetArrivedAt,
            uint256 pendingAttestations,
            bytes32 root
        ) = notary.getPacketDetails(packetId_);

        if (status != INotary.PacketStatus.PROPOSED) return (false, root);
        // if timed out, return true irrespective of fast or slow accum
        if (block.timestamp - packetArrivedAt > timeoutInSeconds)
            return (true, root);

        // if fast, check attestations
        if (isFast) {
            if (pendingAttestations == 0) return (true, root);
        }

        return (false, root);
    }
}

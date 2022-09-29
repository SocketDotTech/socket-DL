// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IVerifier.sol";
import "../interfaces/INotary.sol";
import "../utils/Ownable.sol";

contract Verifier is IVerifier, Ownable {
    INotary public notary;
    uint256 public immutable timeoutInSeconds;

    event NotarySet(address notary_);

    constructor(
        address owner_,
        address _notary,
        uint256 timeoutInSeconds_
    ) Ownable(owner_) {
        notary = INotary(_notary);

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
     * @param accumAddress_ address of accumulator at src
     * @param remoteChainId_ dest chain id
     * @param packetId_ packet id
     */
    function verifyCommitment(
        address accumAddress_,
        uint256 remoteChainId_,
        uint256 packetId_
    ) external view override returns (bool, bytes32) {
        (bool isConfirmed, uint256 packetArrivedAt, bytes32 root) = notary
            .getPacketDetails(accumAddress_, remoteChainId_, packetId_);

        if (isConfirmed) return (true, root);
        if (packetArrivedAt == 0) return (false, root);

        // if timed out
        if (block.timestamp - packetArrivedAt > timeoutInSeconds)
            return (true, root);

        return (false, root);
    }
}

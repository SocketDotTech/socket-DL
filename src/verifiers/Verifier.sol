// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IVerifier.sol";
import "../interfaces/INotary.sol";
import "../interfaces/ISocket.sol";

import "../utils/Ownable.sol";

contract Verifier is IVerifier, Ownable {
    INotary public notary;
    ISocket public socket;
    string public integrationType;
    uint256 public immutable timeoutInSeconds;

    event NotarySet(address notary_);
    event SocketSet(address socket_);

    constructor(
        address owner_,
        address notary_,
        address socket_,
        uint256 timeoutInSeconds_,
        string memory integrationType_
    ) Ownable(owner_) {
        notary = INotary(notary_);
        socket = ISocket(socket_);
        integrationType = integrationType_;

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
     * @notice updates socket
     * @param socket_ address of Socket
     */
    function setSocket(address socket_) external onlyOwner {
        socket = ISocket(socket_);
        emit SocketSet(socket_);
    }

    /**
     * @notice verifies if the packet satisfies needed checks before execution
     * @param accumAddress_ address of accumulator at remote
     * @param remoteChainId_ remote chain id
     * @param packetId_ packet id
     * @param integrationType_ integration type for plug
     */
    function verifyPacket(
        address accumAddress_,
        uint256 remoteChainId_,
        uint256 packetId_,
        bytes32 integrationType_
    ) external view override returns (bool, bytes32) {
        bool isFast = keccak256(abi.encode(integrationType)) == integrationType_
            ? true
            : false;

        (
            INotary.PacketStatus status,
            uint256 packetArrivedAt,
            uint256 pendingAttestations,
            bytes32 root
        ) = notary.getPacketDetails(accumAddress_, remoteChainId_, packetId_);

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

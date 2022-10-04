// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

interface IVerifier {
    /**
     * @notice verifies if the packet satisfies needed checks before execution
     * @param accumAddress_ address of accumulator at src
     * @param remoteChainId_ dest chain id
     * @param packetId_ packet id
     */
    function verifyCommitment(
        address accumAddress_,
        uint256 remoteChainId_,
        uint256 configId_,
        uint256 packetId_
    ) external view returns (bool, bytes32);
}

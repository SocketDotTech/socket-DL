// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

interface IVerifier {
    /**
     * @notice verifies if the packet satisfies needed checks before execution
     * @param accumAddress_ address of accumulator at local
     * @param remoteChainSlug_ remote chain id
     * @param packetId_ packet id
     */
    function verifyPacket(
        address accumAddress_,
        uint256 remoteChainSlug_,
        uint256 packetId_,
        bytes32 integrationType_
    ) external view returns (bool, bytes32);
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

interface IVerifier {
    /**
     * @notice verifies if the packet satisfies needed checks before execution
     * @param packetId_ packet id
     */
    function verifyPacket(uint256 packetId_, bytes32 integrationType_)
        external
        view
        returns (bool, bytes32);
}

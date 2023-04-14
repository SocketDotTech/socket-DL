// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

interface INativeRelay {
    /**
     * @notice receiveMessage on PolygonRootReceiver
     * @param receivePacketProof receivePacketProof
     */
    function receiveMessage(bytes memory receivePacketProof) external;

    function initiateNativeConfirmation(
        bytes32 packetId,
        uint256 maxSubmissionCost,
        uint256 maxGas,
        uint256 gasPriceBid
    ) external payable;

    function initiateNativeConfirmation(bytes32 packetId) external;
}

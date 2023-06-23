// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

/**
 * @title INativeRelay
 * @notice Interface for the NativeRelay contract which is used to relay packets between two chains.
 * It allows for the reception of messages on the PolygonRootReceiver and the initiation of native confirmations
 * for the given packet ID.
 * @dev this is only used by SocketBatcher currently
 */
interface INativeRelay {
    /**
     * @notice receiveMessage on PolygonRootReceiver
     * @param receivePacketProof receivePacketProof The proof of the packet being received on the Polygon network.
     */
    function receiveMessage(bytes memory receivePacketProof) external;

    /**
     * @notice Function to initiate a native confirmation for the given packet ID.
     * @dev The function can be called with maxSubmissionCost, maxGas, and gasPriceBid to customize the confirmation transaction,
     * or with no parameters to use default values.
     * @param packetId The ID of the packet to initiate confirmation for.
     * @param maxSubmissionCost The maximum submission cost of the transaction.
     * @param maxGas The maximum gas limit of the transaction.
     * @param gasPriceBid The gas price bid for the transaction.
     * @param callValueRefundAddress l2 call value gets credited here on L2 if retryable txn times out or gets cancelled
     * @param remoteRefundAddress gasLimit x maxFeePerGas - execution cost gets credited here on L2 balance
     */
    function initiateNativeConfirmation(
        bytes32 packetId,
        uint256 maxSubmissionCost,
        uint256 maxGas,
        uint256 gasPriceBid,
        address callValueRefundAddress,
        address remoteRefundAddress
    ) external payable;

    /**
     * @notice Function to initiate a native confirmation for the given packet ID, using default values for transaction parameters.
     * @param packetId The ID of the packet to initiate confirmation for.
     */
    function initiateNativeConfirmation(bytes32 packetId) external;
}

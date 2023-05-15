// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

/**
 * @title IHasher
 * @notice Interface for hasher contract that calculates the packed message
 */
interface IHasher {
    /**
     * @notice returns the bytes32 hash of the message packed
     * @param srcChainSlug src chain slug
     * @param srcPlug address of plug at source
     * @param dstChainSlug remote chain slug
     * @param dstPlug address of plug at remote
     * @param msgId message id assigned at outbound
     * @param msgGasLimit gas limit which is expected to be consumed by the inbound transaction on plug
     * @param executionFee msg value which is expected to be sent with inbound transaction to plug
     * @param payload the data packed which is used by inbound for execution
     */
    function packMessage(
        uint32 srcChainSlug,
        address srcPlug,
        uint32 dstChainSlug,
        address dstPlug,
        bytes32 msgId,
        uint256 msgGasLimit,
        uint256 executionFee,
        bytes calldata payload
    ) external returns (bytes32);
}

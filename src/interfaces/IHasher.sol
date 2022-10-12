// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

interface IHasher {
    /**
     * @notice returns the bytes32 hash of the message packed
     * @param srcChainId src chain id
     * @param srcPlug address of plug at source
     * @param dstChainId remote chain id
     * @param dstPlug address of plug at remote
     * @param msgId message id assigned at outbound
     * @param msgGasLimit gas limit which is expected to be consumed by the inbound transaction on plug
     * @param payload the data packed which is used by inbound for execution
     */
    function packMessage(
        uint256 srcChainId,
        address srcPlug,
        uint256 dstChainId,
        address dstPlug,
        uint256 msgId,
        uint256 msgGasLimit,
        bytes calldata payload
    ) external returns (bytes32);
}

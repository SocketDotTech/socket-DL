// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "./ISocket.sol";

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
     * @param messageDetails contains message details, see ISocket for more details
     */
    function packMessage(
        uint32 srcChainSlug,
        address srcPlug,
        uint32 dstChainSlug,
        address dstPlug,
        ISocket.MessageDetails memory messageDetails
    ) external returns (bytes32);
}

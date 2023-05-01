// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IHasher.sol";

/**
 * @title Hasher
 * @notice contract for hasher contract that calculates the packed message
 * @dev This contract is modular component in socket to support different message packing algorithms in case of blockchains
 * not supporting this type of packing.
 */
contract Hasher is IHasher {
    /// @inheritdoc IHasher
    function packMessage(
        uint256 srcChainSlug_,
        address srcPlug_,
        uint256 dstChainSlug_,
        address dstPlug_,
        bytes32 msgId_,
        uint256 msgGasLimit_,
        uint256 executionFee_,
        bytes calldata payload_
    ) external pure override returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    srcChainSlug_,
                    srcPlug_,
                    dstChainSlug_,
                    dstPlug_,
                    msgId_,
                    msgGasLimit_,
                    executionFee_,
                    payload_
                )
            );
    }
}

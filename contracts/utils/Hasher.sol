// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IHasher.sol";

contract Hasher is IHasher {
    /// @inheritdoc IHasher
    function packMessage(
        uint256 srcChainSlug,
        address srcPlug,
        uint256 dstChainSlug,
        address dstPlug,
        uint256 msgId,
        uint256 msgGasLimit,
        uint256 msgValue,
        bytes calldata payload
    ) external pure override returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    srcChainSlug,
                    srcPlug,
                    dstChainSlug,
                    dstPlug,
                    msgId,
                    msgGasLimit,
                    msgValue,
                    payload
                )
            );
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

interface IHasher {
    function packMessage(
        uint256 srcChainId,
        address srcPlug,
        uint256 dstChainId,
        address dstPlug,
        uint256 nonce,
        bytes calldata payload
    ) external returns (bytes32);
}

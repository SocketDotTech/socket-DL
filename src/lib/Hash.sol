// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

library Hash  {
    function packMessage(
        uint256 srcChainId,
        address srcPlug,
        uint256 dstChainId,
        address dstPlug,
        uint256 nonce,
        bytes calldata payload
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    srcChainId,
                    srcPlug,
                    dstChainId,
                    dstPlug,
                    nonce,
                    payload
                )
            );
    }
}

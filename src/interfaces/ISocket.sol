// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

contract ISocket {
    function outbound(
        uint256 remoteChainId,
        address remotePlug,
        bytes calldata payload
    ) external;
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

interface IDeaccumulator {
    function verifyPacketHash(
        bytes32 root_,
        bytes32 packetHash_,
        bytes calldata proof_
    ) external pure returns (bool);
}

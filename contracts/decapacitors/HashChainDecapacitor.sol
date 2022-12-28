// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IDecapacitor.sol";

contract HashChainDecapacitor is IDecapacitor {
    /// returns if the packed message is the part of a merkle tree or not
    /// @inheritdoc IDecapacitor
    function verifyMessageInclusion(
        bytes32 root_,
        bytes32 packedMessage_,
        bytes calldata proof
    ) external pure override returns (bool) {
        bytes32[] memory chain = abi.decode(proof, (bytes32[]));
        uint256 len = chain.length;
        bytes32 generatedRoot;
        for (uint256 i = 0; i < len; i++) {
            generatedRoot = keccak256(abi.encode(generatedRoot, chain[i]));
        }
        generatedRoot = keccak256(abi.encode(generatedRoot, packedMessage_));
        return root_ == generatedRoot;
    }
}

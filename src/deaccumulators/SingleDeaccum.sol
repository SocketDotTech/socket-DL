// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../interfaces/IDeaccumulator.sol";

contract SingleDeaccum is IDeaccumulator {
    /// returns if the packed message is the part of a merkle tree or not
    /// @inheritdoc IDeaccumulator
    function verifyMessageInclusion(
        bytes32 root_,
        bytes32 packedMessage_,
        bytes calldata
    ) external pure returns (bool) {
        return root_ == packedMessage_;
    }
}

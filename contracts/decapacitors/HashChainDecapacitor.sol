// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IDecapacitor.sol";
import "../libraries/SafeTransferLib.sol";
import "../utils/Ownable.sol";

contract HashChainDecapacitor is IDecapacitor, Ownable(msg.sender) {
    using SafeTransferLib for IERC20;

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

    function rescueFunds(
        address token,
        address userAddress,
        uint256 amount
    ) external onlyOwner {
        require(userAddress != address(0));

        if (token == address(0)) {
            (bool success, ) = userAddress.call{value: address(this).balance}(
                ""
            );
            require(success);
        } else {
            // do we need safe transfer?
            IERC20(token).transfer(userAddress, amount);
        }
    }
}

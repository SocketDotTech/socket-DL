// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IDecapacitor.sol";
import "../libraries/SafeTransferLib.sol";
import "../utils/Ownable.sol";

contract SingleDecapacitor is IDecapacitor, Ownable(msg.sender) {
    using SafeTransferLib for IERC20;

    /// returns if the packed message is the part of a merkle tree or not
    /// @inheritdoc IDecapacitor
    function verifyMessageInclusion(
        bytes32 root_,
        bytes32 packedMessage_,
        bytes calldata
    ) external pure override returns (bool) {
        return root_ == packedMessage_;
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

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

interface IVerifier {
    function verifyRoot(
        address signer_,
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 batchId_,
        bytes32 root_
    ) external returns (bool);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IVault {
    function deductFee(uint256 remoteChainId_, uint256 msgGasLimit_)
        external
        payable;

    function mintFee(address executer_, uint256 amount_) external;
}

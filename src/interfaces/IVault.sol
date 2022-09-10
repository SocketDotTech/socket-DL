// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IVault {
    event TokenBridged(address account_, uint256 amount_, uint256 chainId_);
    event Claimed(address account_, uint256 amount_);
    event FeeDeducted(uint256 amount_);

    error InsufficientFee();
    error OnlySocket();
    error OnlyNotary();

    function deductFee(uint256 remoteChainId_, uint256 msgGasLimit_)
        external
        payable;

    function mintFee(
        address executer_,
        uint256 amount_,
        uint256 remoteChainId_
    ) external;

    function bridgeTokens(uint256 remoteChainId, uint256 amount)
        external
        payable;

    function setGasPrice(uint256 remoteChainId_, uint256 socketGasPrice_)
        external;

    function getFees(uint256 remoteChainId_, uint256 msgGasLimit_)
        external
        view
        returns (uint256);
}

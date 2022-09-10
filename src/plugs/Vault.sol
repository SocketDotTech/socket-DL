// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../utils/Ownable.sol";
import "../interfaces/IVault.sol";
import "../interfaces/INotary.sol";
import "../interfaces/IPlug.sol";
import "../interfaces/ISocket.sol";

contract Vault is IVault, IPlug, ReentrancyGuard, Ownable, ERC20 {
    ISocket public socket;
    INotary public notary;

    // includes cost of propose + confirmRoot + executeCost
    mapping(uint256 => uint256) public attesterDestGasLimit;

    // gas price in dest native token
    mapping(uint256 => uint256) public socketGasPrice;

    // gas needed to verifyAndSeal
    uint256 public attesterSrcGasLimit;

    // extra to manage price volatility
    uint256 public bufferPrice;

    uint256 public bridgeGasLimit;

    constructor(
        string memory name_,
        string memory symbol_,
        address owner_,
        address notary_
    ) ERC20(name_, symbol_) Ownable(owner_) {
        notary = INotary(notary_);
    }

    function deductFee(uint256 remoteChainId_, uint256 msgGasLimit_)
        external
        payable
        nonReentrant
    {
        uint256 fee = (attesterSrcGasLimit * tx.gasprice) +
            (msgGasLimit_ + attesterDestGasLimit[remoteChainId_]) *
            socketGasPrice[remoteChainId_] +
            bufferPrice;

        if (fee > msg.value) revert InsufficientFee();
        emit FeeDeducted(fee);
    }

    function mintFee(
        address executer_,
        uint256 amount_,
        uint256 remoteChainId_
    ) external {
        if (msg.sender != address(socket)) revert OnlySocket();
        super._mint(executer_, amount_ * socketGasPrice[remoteChainId_]);
        require(address(this).balance >= totalSupply());
    }

    function inbound(bytes calldata payload_) external nonReentrant {
        require(msg.sender == address(socket), "Counter: Invalid Socket");
        (address to, uint256 amount) = abi.decode(payload_, (address, uint256));

        _transfer(to, amount);
    }

    function _transfer(address account_, uint256 amount_) internal {
        // Send ETH equal to the tokens burned
        (bool success, ) = account_.call{value: amount_}("");
        require(success, "Transfer failed.");

        // As outbound will be sending ETH
        require(address(this).balance >= totalSupply());

        emit Claimed(account_, amount_);
    }

    function bridgeTokens(uint256 remoteChainId, uint256 amount)
        external
        payable
    {
        _burn(_msgSender(), amount);

        bytes memory payload = abi.encode(msg.sender, amount);
        _outbound(remoteChainId, payload);
    }

    function _outbound(uint256 targetChain, bytes memory payload) private {
        ISocket(socket).outbound(targetChain, bridgeGasLimit, payload);
    }

    function getStuckETHOut(address account_, uint256 amount_)
        external
        onlyOwner
    {
        // also burn amount_ from account_? can be useful in case of emergency so not sure
        (bool success, ) = account_.call{value: amount_}("");
        require(success, "Transfer failed.");
    }

    function setGasPrice(uint256 remoteChainId_, uint256 socketGasPrice_)
        external
    {
        if (msg.sender != address(notary)) revert OnlyNotary();
        socketGasPrice[remoteChainId_] = socketGasPrice_;
    }

    function setGasDetails(
        uint256 remoteChainId_,
        uint256 attesterDestGasLimit_,
        uint256 attesterSrcGasLimit_,
        uint256 bufferPrice_,
        uint256 bridgeGasLimit_
    ) external onlyOwner {
        attesterDestGasLimit[remoteChainId_] = attesterDestGasLimit_;
        attesterSrcGasLimit = attesterSrcGasLimit_;
        bufferPrice = bufferPrice_;
        bridgeGasLimit = bridgeGasLimit_;
    }

    // add function in socket to transfer ownership to new socket if upgraded
    function setSocket(address socket_) external onlyOwner {
        socket = ISocket(socket_);
    }

    function getFees(uint256 remoteChainId_, uint256 msgGasLimit_)
        external
        view
        returns (uint256)
    {
        return
            (attesterSrcGasLimit * tx.gasprice) +
            (msgGasLimit_ + attesterDestGasLimit[remoteChainId_]) *
            socketGasPrice[remoteChainId_] +
            bufferPrice;
    }
}

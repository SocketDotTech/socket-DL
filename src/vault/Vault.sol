// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../utils/Ownable.sol";
import "../interfaces/IVault.sol";
import "../interfaces/INotary.sol";
import "../interfaces/IPlug.sol";
import "../interfaces/ISocket.sol";
import "./SocketGasToken.sol";

contract Vault is IVault, IPlug, ReentrancyGuard, Ownable {
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

    mapping(uint256 => address) public destTokens;

    constructor(address owner_, address notary_) Ownable(owner_) {
        notary = INotary(notary_);
    }

    /// @inheritdoc IVault
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

    /// @inheritdoc IVault
    function mintFee(
        address executer_,
        uint256 amount_,
        uint256 remoteChainId_
    ) external {
        address sgt = _getDestToken(remoteChainId_);
        if (msg.sender != address(socket)) revert OnlySocket();

        SocketGasToken(sgt).mint(
            executer_,
            amount_ * socketGasPrice[remoteChainId_]
        );
        require(address(this).balance >= SocketGasToken(sgt).totalSupply());
    }

    function _getDestToken(uint256 remoteChainId_)
        internal
        returns (address token)
    {
        if (token == address(0)) {
            SocketGasToken sgt = new SocketGasToken(remoteChainId_);
            destTokens[remoteChainId_] = address(sgt);
        }
        return destTokens[remoteChainId_];
    }

    /// @inheritdoc IPlug
    function inbound(bytes calldata payload_) external nonReentrant {
        require(msg.sender == address(socket), "Counter: Invalid Socket");
        (address to, uint256 amount) = abi.decode(payload_, (address, uint256));

        _transfer(to, amount);
    }

    function _transfer(address account_, uint256 amount_) internal {
        // Send ETH equal to the tokens burned
        (bool success, ) = account_.call{value: amount_}("");
        require(success, "Transfer failed.");

        emit Claimed(account_, amount_);
    }

    /// @inheritdoc IVault
    function bridgeTokens(uint256 remoteChainId, uint256 amount)
        external
        payable
    {
        SocketGasToken(destTokens[remoteChainId]).burnFrom(msg.sender, amount);

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

    /// @inheritdoc IVault
    function setSocketGasPrice(uint256 remoteChainId_, uint256 socketGasPrice_)
        external
    {
        if (msg.sender != address(notary)) revert OnlyNotary();
        socketGasPrice[remoteChainId_] = socketGasPrice_;
    }

    /**
     * @notice sets the gas details for fee calculation
     * @param remoteChainId_ dest chain id
     * @param attesterSrcGasLimit_ gas limit needed for executing verifyAndSeal
     * @param attesterDestGasLimit_ gas limit needed for executing propose and confirm
     * @param bufferPrice_ extra price in native token to balance price volatility
     * @param bridgeGasLimit_ gas limit needed to bridge tokens from socket (used by outbound)
     */
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

    /// to register new socket if upgraded
    function setSocket(address socket_) external onlyOwner {
        socket = ISocket(socket_);
    }

    /// @inheritdoc IVault
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

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../utils/AccessControl.sol";
import "../interfaces/IVault.sol";
import "../interfaces/INotary.sol";

contract Vault is IVault, AccessControl(msg.sender), ERC20 {
    address public socket;
    INotary public notary;

    bytes32 MINTER_ROLE = keccak256("MINTER");

    // for updating balances bridged from destination chain
    bytes32 ATTESTER_ROLE = keccak256("ATTESTER");

    error InsufficientFee();

    constructor(
        string memory name_,
        string memory symbol_,
        address owner_,
        address notary_
    ) ERC20(name_, symbol_) AccessControl(owner_) {
        notary = notary_;
    }

    function deductFee(uint256 remoteChainId_, uint256 msgGasLimit_)
        external
        payable
        nonReentrant
    {
        (
            uint256 attesterSrcGasLimit,
            uint256 attesterDestGasLimit,
            uint256 socketGasPrice,
            uint256 bufferPrice
        ) = notary.getFeeDetails(remoteChainId_);

        uint256 fee = (attesterSrcGasLimit * tx.gasprice) +
            (msgGasLimit_ + attesterDestGasLimit[remoteChainId_]) *
            socketGasPrice +
            bufferPrice;

        (bool success, ) = address(_vault).call{value: fee}("");
        require(success, "Transfer failed.");

        if (fee > msg.value) revert InsufficientFee();
    }

    function mintFee(address executer_, uint256 amount_) external {
        if (!_hasRole(MINTER_ROLE, _msgSender())) revert NotMinter();
        super._mint(account_, amount_);
        require(address(this).balance >= totalSupply());
    }

    // add function in socket to transfer ownership to new socket if upgraded
    function setSocket(address socket_) external onlyOwner {
        _grantRole(MINTER_ROLE, socket_);
        socket = socket_;
    }

    function bridge(uint256 amount_) external {
        _burn(msg.sender, amount_);
        emit TokenBridged(msg.sender, amount_, block.chainid);
    }

    // might not be needed
    function claim(uint256 amount_) external {
        _burnAndTransfer(msg.sender, amount_);
    }

    function claimAll() external {
        _burnAndTransfer(msg.sender, balanceOf(msg.sender));
    }

    function _burnAndTransfer(address account_, uint256 amount_) internal {
        _burn(account_, amount_);

        // Send ETH equal to the tokens burned
        (bool success, ) = account_.call{value: amount_}("");
        require(success, "Transfer failed.");

        // As outbound will be sending ETH
        require(address(this).balance >= totalSupply());

        emit Claimed(account_, amount_);
    }

    function getStuckETHOut(address account_, uint256 amount_)
        external
        onlyOwner
    {
        // also burn amount_ from account_? can be useful in case of emergency so not sure
        (bool success, ) = account_.call{value: amount_}("");
        require(success, "Transfer failed.");
    }

    receive() external payable {
        require(msg.sender == socket);
        // should we update balance?
    }
}

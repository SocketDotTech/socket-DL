// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IVault {
    /**
     * @notice emits when a packet is bridged from current chain to chainId_
     * @param account_ address of user
     * @param amount_ total tokens bridged
     * @param chainId_ dest chain id
     */
    event TokenBridged(address account_, uint256 amount_, uint256 chainId_);

    /**
     * @notice emits when a user claims the token at src
     * @param account_ address of user
     * @param amount_ native tokens claimed
     */
    event Claimed(address account_, uint256 amount_);

    /**
     * @notice emits when fee is deducted at outbound
     * @param amount_ total fee amount
     */
    event FeeDeducted(uint256 amount_);

    error InsufficientFee();
    error OnlySocket();
    error OnlyNotary();

    /**
     * @notice deducts the fee required to bridge the packet using msgGasLimit
     * @param remoteChainId_ dest chain id
     * @param msgGasLimit_ gas limit needed to execute inbound at remote plug
     */
    function deductFee(uint256 remoteChainId_, uint256 msgGasLimit_)
        external
        payable;

    /**
     * @notice mints the fee token at dest to the executor
     * @param executer_ address of executer
     * @param amount_ amount to be minted
     * @param remoteChainId_ dest chain id
     */
    function mintFee(
        address executer_,
        uint256 amount_,
        uint256 remoteChainId_
    ) external;

    /**
     * @notice bridges token to dest
     * @param remoteChainId_ dest chain id
     * @param amount_ amount to be bridged
     */
    function bridgeTokens(uint256 remoteChainId_, uint256 amount_)
        external
        payable;

    /**
     * @notice sets the gas price
     * @param remoteChainId_ dest chain id
     * @param socketGasPrice_ this price is the gas price at destination including the buffer needed.
     */
    function setGasPrice(uint256 remoteChainId_, uint256 socketGasPrice_)
        external;

    /**
     * @notice returns the fee required to bridge a message
     * @param remoteChainId_ dest chain id
     * @param msgGasLimit_ gas limit needed to execute inbound at remote plug
     */
    function getFees(uint256 remoteChainId_, uint256 msgGasLimit_)
        external
        view
        returns (uint256);
}

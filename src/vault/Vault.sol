// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../utils/Ownable.sol";
import "../interfaces/IVault.sol";

contract Vault is IVault, Ownable {
    // integration type from socket => remote chain slug => fees
    mapping(bytes32 => mapping(uint256 => uint256)) public minFees;

    error InsufficientFees();

    /**
     * @notice emits when fee is deducted at outbound
     * @param amount_ total fee amount
     */
    event FeeDeducted(uint256 amount_);
    event FeesSet(
        uint256 minFees_,
        uint256 remoteChainSlug_,
        bytes32 integrationType_
    );

    constructor(address owner_) Ownable(owner_) {}

    /// @inheritdoc IVault
    function deductFee(uint256 remoteChainSlug_, bytes32 integrationType_)
        external
        payable
        override
    {
        if (msg.value < minFees[integrationType_][remoteChainSlug_])
            revert InsufficientFees();
        emit FeeDeducted(msg.value);
    }

    /**
     * @notice updates the fee required to bridge a message for give chain and config
     * @param minFees_ fees
     * @param integrationType_ config for which fees is needed
     * @param integrationType_ config for which fees is needed
     */
    function setFees(
        uint256 minFees_,
        uint256 remoteChainSlug_,
        bytes32 integrationType_
    ) external onlyOwner {
        minFees[integrationType_][remoteChainSlug_] = minFees_;
        emit FeesSet(minFees_, remoteChainSlug_, integrationType_);
    }

    /**
     * @notice transfers the `amount_` ETH to `account_`
     * @param account_ address to transfer ETH
     * @param amount_ amount to transfer
     */
    function claimFee(address account_, uint256 amount_) external onlyOwner {
        require(account_ != address(0));
        (bool success, ) = account_.call{value: amount_}("");
        require(success, "Transfer failed.");
    }

    /**
     * @notice returns the fee required to bridge a message
     * @param integrationType_ config for which fees is needed
     */
    function getFees(bytes32 integrationType_, uint256 remoteChainSlug_)
        external
        view
        returns (uint256)
    {
        return minFees[integrationType_][remoteChainSlug_];
    }
}

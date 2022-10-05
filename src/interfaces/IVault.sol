// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

interface IVault {
    /**
     * @notice emits when fee is deducted at outbound
     * @param amount_ total fee amount
     */
    event FeeDeducted(uint256 amount_);

    event FeesSet(uint256 minFees_, uint256 configId_);

    error InsufficientFee();
    error NotEnoughFees();

    /**
     * @notice deducts the fee required to bridge the packet using msgGasLimit
     * @param remoteChainId_ dest chain id
     * @param configId_ config used by the plug to calculate the fees
     */
    function deductFee(uint256 remoteChainId_, uint256 configId_)
        external
        payable;

    /**
     * @notice transfers the `amount_` ETH to `account_`
     * @param account_ address to transfer ETH
     * @param amount_ amount to transfer
     */
    function claimFee(address account_, uint256 amount_) external;

    /**
     * @notice returns the fee required to bridge a message
     * @param configId_ config for which fees is needed
     */
    function getFees(uint256 configId_) external view returns (uint256);

    function setFees(uint256 minFees_, uint256 configId_) external;
}

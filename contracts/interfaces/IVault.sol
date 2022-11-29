// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

interface IVault {
    /**
     * @notice deducts the fee required to bridge the packet using msgGasLimit
     * @param remoteChainSlug_ remote chain slug
     * @param integrationType_ for the given message
     */
    function deductFee(
        uint256 remoteChainSlug_,
        bytes32 integrationType_
    ) external payable;

    /**
     * @notice deducts the fee required to retry a message which is already executed but failed.
     */
    function deductRetryFee() external payable;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

interface IVault {
    /**
     * @notice deducts the fee required to bridge the packet using msgGasLimit
     * @param remoteChainId_ remote chain id
     * @param integrationType_ for the given message
     */
    function deductFee(uint256 remoteChainId_, bytes32 integrationType_)
        external
        payable;
}

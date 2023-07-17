// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

/**
 * @title ITransmitManager
 * @dev The interface for a transmit manager contract
 */
interface ITransmitManager {
    /**
     * @notice Checks if a given transmitter is authorized to send transactions to the destination chain.
     * @param siblingSlug The unique identifier for the sibling chain.
     * @param digest The digest of the message being signed.
     * @param signature The signature of the message being signed.
     * @return The address of the transmitter and a boolean indicating whether the transmitter is authorized or not.
     */
    function checkTransmitter(
        uint32 siblingSlug,
        bytes32 digest,
        bytes calldata signature
    ) external view returns (address, bool);

    /**
     * @notice sets the transmission fee needed to transmit message to given `siblingSlug_`
     * @dev recovered address should add have feeUpdater role for `siblingSlug_`
     * @param nonce_ The incremental nonce to prevent signature replay
     * @param siblingSlug_ sibling id for which fee updater is registered
     * @param transmissionFees_ digest which is signed by transmitter
     * @param signature_ signature
     */
    function setTransmissionFees(
        uint256 nonce_,
        uint32 siblingSlug_,
        uint128 transmissionFees_,
        bytes calldata signature_
    ) external;

    /**
     * @notice receives fees from Execution manager
     * @dev this function can be used to keep track of fees received for each slug
     * @param siblingSlug_ sibling id for which fee updater is registered
     */
    function receiveFees(uint32 siblingSlug_) external payable;
}

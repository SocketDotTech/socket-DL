// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

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
     * @notice Pays the fees required for the destination chain to process the packet.
     * @dev The fees are paid by the sender of the packet to the transmit manager contract.
     * @param dstSlug The unique identifier for the destination chain of the packet.
     */
    function payFees(uint32 dstSlug) external payable;

    /**
     * @notice Retrieves the minimum fees required for the destination chain to process the packet.
     * @param dstSlug The unique identifier for the destination chain of the packet.
     * @return The minimum fee required for the destination chain to process the packet.
     */
    function getMinFees(uint32 dstSlug) external view returns (uint256);

    function setTransmissionFees(
        uint256 nonce_,
        uint32 dstChainSlug_,
        uint256 transmissionFees_,
        bytes calldata signature_
    ) external;
}

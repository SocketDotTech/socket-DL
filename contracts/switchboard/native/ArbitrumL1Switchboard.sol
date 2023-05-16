// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "openzeppelin-contracts/contracts/vendor/arbitrum/IBridge.sol";
import "openzeppelin-contracts/contracts/vendor/arbitrum/IInbox.sol";
import "openzeppelin-contracts/contracts/vendor/arbitrum/IOutbox.sol";

import "./NativeSwitchboardBase.sol";

import {ARBITRUM_NATIVE_FEE_UPDATE_SIG_IDENTIFIER} from "../../utils/SigIdentifiers.sol";

/**
 * @title ArbitrumL1Switchboard
 * @dev This contract is a switchboard contract for the Arbitrum chain that handles packet attestation and actions on the L1 to Arbitrum and
 * Arbitrum to L1 path.
 * This contract inherits base functions from NativeSwitchboardBase, including fee calculation,
 * trip and untrip actions, and limit setting functions.
 */
contract ArbitrumL1Switchboard is NativeSwitchboardBase {
    /**
     * @notice The address to which refunds for remote calls will be sent.
     */
    address public remoteRefundAddress;

    /**
     * @notice The address to which refunds for call value will be sent.
     */
    address public callValueRefundAddress;

    /**
     * @notice The fee charged in Arbitrum native currency for executing transactions.
     */
    uint256 public arbitrumNativeFee;

    /**
     * @notice An interface for receiving incoming messages from the Arbitrum chain.
     */
    IInbox public inbox__;

    /**
     * @notice An interface for the Arbitrum-to-Ethereum bridge.
     */
    IBridge public bridge__;

    /**
     * @notice An interface for the Ethereum-to-Arbitrum outbox.
     */
    IOutbox public outbox__;

    /**
     * @notice Event emitted when the inbox address is updated.
     * @param inbox The new inbox address.
     */
    event UpdatedInboxAddress(address inbox);

    /**
     * @notice Event emitted when the remote and call value refund addresses are updated.
     * @param remoteRefundAddress The new remote refund address.
     * @param callValueRefundAddress The new call value refund address.
     */
    event UpdatedRefundAddresses(
        address remoteRefundAddress,
        address callValueRefundAddress
    );

    /**
     * @notice Event emitted when the Arbitrum native fee is updated.
     * @param arbitrumNativeFee The new Arbitrum native fee.
     */
    event UpdatedArbitrumNativeFee(uint256 arbitrumNativeFee);

    /**
     * @notice Event emitted when the bridge address is updated.
     * @param bridgeAddress The new bridge address.
     */
    event UpdatedBridge(address bridgeAddress);

    /**
     * @notice Event emitted when the outbox address is updated.
     * @param outboxAddress The new outbox address.
     */
    event UpdatedOutbox(address outboxAddress);

    /**
     * @notice Modifier that restricts access to the function to the remote switchboard.
     */
    modifier onlyRemoteSwitchboard() override {
        if (msg.sender != address(bridge__)) revert InvalidSender();
        address l2Sender = outbox__.l2ToL1Sender();
        if (l2Sender != remoteNativeSwitchboard) revert InvalidSender();
        _;
    }

    /**
     * @dev Constructor function for initializing the NativeBridge contract
     * @param chainSlug_ The identifier of the current chain in the system
     * @param arbitrumNativeFee_ The fee charged by the system for processing messages
     * @param initiateGasLimit_ The maximum gas limit that can be used for initiating a message
     * @param inbox_ The address of the Arbitrum Inbox contract
     * @param owner_ The address of the owner of the NativeBridge contract
     * @param socket_ The address of the socket contract
     * @param gasPriceOracle_ The address of the gas price oracle contract
     * @param bridge_ The address of the bridge contract
     * @param outbox_ The address of the Arbitrum Outbox contract
     */
    constructor(
        uint32 chainSlug_,
        uint256 arbitrumNativeFee_,
        uint256 initiateGasLimit_,
        address inbox_,
        address owner_,
        address socket_,
        IGasPriceOracle gasPriceOracle_,
        address bridge_,
        address outbox_,
        ISignatureVerifier signatureVerifier_
    )
        AccessControlExtended(owner_)
        NativeSwitchboardBase(
            socket_,
            chainSlug_,
            initiateGasLimit_,
            gasPriceOracle_,
            signatureVerifier_
        )
    {
        inbox__ = IInbox(inbox_);
        arbitrumNativeFee = arbitrumNativeFee_;

        bridge__ = IBridge(bridge_);
        outbox__ = IOutbox(outbox_);

        remoteRefundAddress = msg.sender;
        callValueRefundAddress = msg.sender;
    }

    /**
     * @notice This function is used to initiate a native confirmation.
     *         this is invoked in L1 to L2 and L2 to L1 paths
     *
     * @param packetId_ (bytes32) The ID of the packet to confirm.
     * @param maxSubmissionCost_ (uint256) The maximum submission cost for the retryable ticket.
     * @param maxGas_ (uint256) The maximum gas allowed for the retryable ticket.
     * @param gasPriceBid_ (uint256) The gas price bid for the retryable ticket.
     * @dev     encodes the remote call and creates a retryable ticket using the inbox__ contract.
     *          Finally, it emits the InitiatedNativeConfirmation event.
     */
    function initiateNativeConfirmation(
        bytes32 packetId_,
        uint256 maxSubmissionCost_,
        uint256 maxGas_,
        uint256 gasPriceBid_
    ) external payable {
        bytes memory data = _encodeRemoteCall(packetId_);

        // to avoid stack too deep
        address callValueRefund = callValueRefundAddress;
        address remoteRefund = remoteRefundAddress;

        inbox__.createRetryableTicket{value: msg.value}(
            remoteNativeSwitchboard,
            0, // no value needed for receivePacket
            maxSubmissionCost_,
            remoteRefund,
            callValueRefund,
            maxGas_,
            gasPriceBid_,
            data
        );

        emit InitiatedNativeConfirmation(packetId_);
    }

    /**
     * @notice This function is used to encode data to create retryableTicket on inbox
     * @param packetId_ (bytes32): The ID of the packet to confirm.
     * @return data encoded-data (packetId)
     * @dev  encodes the remote call used to create a retryable ticket using the inbox__ contract.
     */
    function _encodeRemoteCall(
        bytes32 packetId_
    ) internal view returns (bytes memory data) {
        data = abi.encodeWithSelector(
            this.receivePacket.selector,
            packetId_,
            _getRoot(packetId_)
        );
    }

    /**
     * @notice This function updates the remote and call value refund addresses for the contract.
     *         Only users with the GOVERNANCE_ROLE can call this function.
     * @param remoteRefundAddress_  (address): The new address that will be used to refund remote tokens.
     * @param callValueRefundAddress_ (address): The new address that will be used to refund call values.
     * @dev  Ensures that only users with the GOVERNANCE_ROLE can call this function.
     */
    function updateRefundAddresses(
        address remoteRefundAddress_,
        address callValueRefundAddress_
    ) external onlyRole(GOVERNANCE_ROLE) {
        remoteRefundAddress = remoteRefundAddress_;
        callValueRefundAddress = callValueRefundAddress_;

        emit UpdatedRefundAddresses(
            remoteRefundAddress_,
            callValueRefundAddress_
        );
    }

    /**
     * @notice updates the address of the inbox contract that is used to communicate with the Arbitrum Rollup.
     * @dev This function can only be called by a user with the GOVERNANCE_ROLE.
     * @param inbox_ address of new inbox to be updated
     */
    function updateInboxAddresses(
        address inbox_
    ) external onlyRole(GOVERNANCE_ROLE) {
        inbox__ = IInbox(inbox_);
        emit UpdatedInboxAddress(inbox_);
    }

    /**
     * @notice updates the address of the bridge contract that is used to communicate with the Arbitrum Rollup.
     * @dev This function can only be called by a user with the GOVERNANCE_ROLE.
     * @param bridgeAddress_ address of new bridge to be updated
     */
    function updateBridge(
        address bridgeAddress_
    ) external onlyRole(GOVERNANCE_ROLE) {
        bridge__ = IBridge(bridgeAddress_);

        emit UpdatedBridge(bridgeAddress_);
    }

    /**
     * @notice Updates the address of the outbox__ contract that this contract is configured to use.
     * @param outboxAddress_ The address of the new outbox__ contract to use.
     * @dev This function can only be called by an address with the GOVERNANCE_ROLE.
     * @dev Emits an UpdatedOutbox event with the updated outboxAddress_.
     */
    function updateOutbox(
        address outboxAddress_
    ) external onlyRole(GOVERNANCE_ROLE) {
        outbox__ = IOutbox(outboxAddress_);

        emit UpdatedOutbox(outboxAddress_);
    }
}

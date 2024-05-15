// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "openzeppelin-contracts/contracts/vendor/optimism/ICrossDomainMessenger.sol";
import "./NativeSwitchboardBase.sol";
import {SOCKET_RELAYER_ROLE} from "../../utils/AccessRoles.sol";

/**
 * @title OptimismSwitchboard
 * @dev A contract that acts as a switchboard for native tokens between L1 and L2 networks in the Optimism Layer 2 solution.
 *      This contract extends the NativeSwitchboardBase contract and implements the required functions to interact with the
 *      CrossDomainMessenger contract, which is used to send and receive messages between L1 and L2 networks in the Optimism solution.
 */
contract OptimismSwitchboard is NativeSwitchboardBase {
    uint256 public receiveGasLimit;

    ICrossDomainMessenger public immutable crossDomainMessenger__;

    event UpdatedReceiveGasLimit(uint256 receiveGasLimit);

    /**
     * @dev Modifier that checks if the sender of the function is the CrossDomainMessenger contract or the remoteNativeSwitchboard address.
     *      This modifier is inherited from the NativeSwitchboardBase contract and is used to ensure that only authorized entities can access the switchboard functions.
     */
    modifier onlyRemoteSwitchboard() override {
        if (
            msg.sender != address(crossDomainMessenger__) ||
            crossDomainMessenger__.xDomainMessageSender() !=
            remoteNativeSwitchboard
        ) revert InvalidSender();
        _;
    }

    /**
     * @dev Constructor function that initializes the OptimismSwitchboard contract with the required parameters.
     * @param chainSlug_ The unique identifier for the chain on which this contract is deployed.
     * @param receiveGasLimit_ The gas limit to be used when receiving messages from the remote switchboard contract.
     * @param owner_ The address of the owner of the contract who has access to the administrative functions.
     * @param socket_ The address of the socket contract that will be used to communicate with the chain.
     * @param crossDomainMessenger_ The address of the CrossDomainMessenger contract that will be used to send and receive messages between L1 and L2 networks in the Optimism solution.
     */
    constructor(
        uint32 chainSlug_,
        uint256 receiveGasLimit_,
        address owner_,
        address socket_,
        address crossDomainMessenger_,
        ISignatureVerifier signatureVerifier_
    )
        AccessControlExtended(owner_)
        NativeSwitchboardBase(socket_, chainSlug_, signatureVerifier_)
    {
        receiveGasLimit = receiveGasLimit_;
        crossDomainMessenger__ = ICrossDomainMessenger(crossDomainMessenger_);
    }

    /**
     * @dev Function used to initiate a confirmation of a native token transfer from the remote switchboard contract.
     * @param packetId_ The identifier of the packet containing the details of the native token transfer.
     */
    function initiateNativeConfirmation(bytes32 packetId_) external onlyRole(SOCKET_RELAYER_ROLE) {
        bytes memory data = _encodeRemoteCall(packetId_);

        crossDomainMessenger__.sendMessage(
            remoteNativeSwitchboard,
            data,
            uint32(receiveGasLimit)
        );
        emit InitiatedNativeConfirmation(packetId_);
    }

    /**
     * @dev Encodes the arguments for the receivePacket function to be called on the remote switchboard contract, and returns the encoded data.
     * @param packetId_ the ID of the packet being sent.
     * @return data  encoded data.
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
     * @notice Update the gas limit for receiving messages from the remote switchboard.
     * @dev Can only be called by accounts with the GOVERNANCE_ROLE.
     * @param receiveGasLimit_ The new receive gas limit to set.
     */
    function updateReceiveGasLimit(
        uint256 receiveGasLimit_
    ) external onlyRole(GOVERNANCE_ROLE) {
        receiveGasLimit = receiveGasLimit_;
        emit UpdatedReceiveGasLimit(receiveGasLimit_);
    }
}

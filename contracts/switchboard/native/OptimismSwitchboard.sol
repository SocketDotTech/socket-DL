// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "openzeppelin-contracts/contracts/vendor/optimism/ICrossDomainMessenger.sol";
import "./NativeSwitchboardBase.sol";

/**
 * @title OptimismSwitchboard
 * @dev A contract that acts as a switchboard for native tokens between L1 and L2 networks in the Optimism Layer 2 solution.
 *      This contract extends the NativeSwitchboardBase contract and implements the required functions to interact with the
 *      CrossDomainMessenger contract, which is used to send and receive messages between L1 and L2 networks in the Optimism solution.
 */
contract OptimismSwitchboard is NativeSwitchboardBase {
    uint256 public receiveGasLimit;
    uint256 public confirmGasLimit;

    ICrossDomainMessenger public immutable crossDomainMessenger__;

    event UpdatedReceiveGasLimit(uint256 receiveGasLimit);
    event UpdatedConfirmGasLimit(uint256 confirmGasLimit);

    /**
     * @dev Modifier that checks if the sender of the function is the CrossDomainMessenger contract or the remoteNativeSwitchboard address.
     *      This modifier is inherited from the NativeSwitchboardBase contract and is used to ensure that only authorized entities can access the switchboard functions.
     */
    modifier onlyRemoteSwitchboard() override {
        if (
            msg.sender != address(crossDomainMessenger__) &&
            crossDomainMessenger__.xDomainMessageSender() !=
            remoteNativeSwitchboard
        ) revert InvalidSender();
        _;
    }

    /**
     * @dev Constructor function that initializes the OptimismSwitchboard contract with the required parameters.
     * @param chainSlug_ The unique identifier for the chain on which this contract is deployed.
     * @param receiveGasLimit_ The gas limit to be used when receiving messages from the remote switchboard contract.
     * @param confirmGasLimit_ The gas limit to be used when confirming messages from the remote switchboard contract.
     * @param initiateGasLimit_ The gas limit to be used when initiating messages to the remote switchboard contract.
     * @param executionOverhead_ The estimated execution overhead cost in gas for executing a transaction.
     * @param owner_ The address of the owner of the contract who has access to the administrative functions.
     * @param socket_ The address of the socket contract that will be used to communicate with the chain.
     * @param gasPriceOracle_ The address of the gas price oracle contract that will be used to determine the gas price.
     * @param crossDomainMessenger_ The address of the CrossDomainMessenger contract that will be used to send and receive messages between L1 and L2 networks in the Optimism solution.
     */
    constructor(
        uint32 chainSlug_,
        uint256 receiveGasLimit_,
        uint256 confirmGasLimit_,
        uint256 initiateGasLimit_,
        uint256 executionOverhead_,
        address owner_,
        address socket_,
        IGasPriceOracle gasPriceOracle_,
        address crossDomainMessenger_,
        ISignatureVerifier signatureVerifier_
    )
        AccessControlExtended(owner_)
        NativeSwitchboardBase(
            socket_,
            chainSlug_,
            initiateGasLimit_,
            executionOverhead_,
            gasPriceOracle_,
            signatureVerifier_
        )
    {
        receiveGasLimit = receiveGasLimit_;
        confirmGasLimit = confirmGasLimit_;
        crossDomainMessenger__ = ICrossDomainMessenger(crossDomainMessenger_);
    }

    /**
     * @dev Function used to initiate a confirmation of a native token transfer from the remote switchboard contract.
     * @param packetId_ The identifier of the packet containing the details of the native token transfer.
     */
    function initiateNativeConfirmation(bytes32 packetId_) external {
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
     * @dev Encodes the arguments for the receivePacket function to be called on the remote switchboard contract, and returns the encoded data.
     * @param dstRelativeGasPrice_  the relative gas price on the destination chain.
     * @return sourceGasPrice_   the gas price on the source chain.
     * @dev required to relay the transaction. The fee is calculated as the product of the
     *       initiateGasLimit and sourceGasPrice_, plus the product of the confirmGasLimit and dstRelativeGasPrice_.
     *       If the confirmGasLimit is 0, it is not included in the calculation.
     */
    function _getMinSwitchboardFees(
        uint32,
        uint256 dstRelativeGasPrice_,
        uint256 sourceGasPrice_
    ) internal view override returns (uint256) {
        // confirmGasLimit will be 0 when switchboard is deployed on L1
        return
            initiateGasLimit *
            sourceGasPrice_ +
            confirmGasLimit *
            dstRelativeGasPrice_;
    }

    /**
     * @dev Updates the confirmation gas limit for native transactions initiated by the switchboard.
     *       This function can only be called by an address with GAS_LIMIT_UPDATER_ROLE role.
     *       The nonce_ argument is used to prevent replay attacks.
     *       The signature_ argument is used to authenticate the request.
     * @param nonce_ The nonce to be used in the signature verification.
     * @param confirmGasLimit_ The new confirmation gas limit to be set.
     * @param signature_ The signature used to authenticate the request.
     */
    function updateConfirmGasLimit(
        uint256 nonce_,
        uint256 confirmGasLimit_,
        bytes memory signature_
    ) external {
        address gasLimitUpdater = SignatureVerifierLib.recoverSignerFromDigest(
            keccak256(
                abi.encode(
                    L1_RECEIVE_GAS_LIMIT_UPDATE_SIG_IDENTIFIER,
                    address(this),
                    chainSlug,
                    nonce_,
                    confirmGasLimit_
                )
            ),
            signature_
        );

        _checkRole(GAS_LIMIT_UPDATER_ROLE, gasLimitUpdater);
        uint256 nonce = nextNonce[gasLimitUpdater]++;
        if (nonce_ != nonce) revert InvalidNonce();

        confirmGasLimit = confirmGasLimit_;
        emit UpdatedConfirmGasLimit(confirmGasLimit_);
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

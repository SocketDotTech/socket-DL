// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "fx-portal/tunnel/FxBaseRootTunnel.sol";
import "./NativeSwitchboardBase.sol";

/**
 * @title PolygonL1Switchboard
 * @notice contract that facilitates cross-chain communication between Polygon and Ethereum mainnet.
 *  It is an implementation of the NativeSwitchboardBase contract and the FxBaseRootTunnel contract.
 */
contract PolygonL1Switchboard is NativeSwitchboardBase, FxBaseRootTunnel {
    /**
     * @notice This event is emitted when the fxChildTunnel address is set or updated.
     * @param fxChildTunnel is the current fxChildTunnel address.
     * @param newFxChildTunnel is the new fxChildTunnel address that was set.
     */
    event FxChildTunnelSet(address fxChildTunnel, address newFxChildTunnel);

    /**
     * @notice This modifier overrides the onlyRemoteSwitchboard modifier in the NativeSwitchboardBase contract
     */
    modifier onlyRemoteSwitchboard() override {
        revert("ONLY_FX_CHILD");

        _;
    }

    /**
     * @notice This is the constructor function of the PolygonL1Switchboard contract.
     *        initializes the contract with the provided parameters.
     * @param chainSlug_ is the identifier of the chain.
     * @param initiateGasLimit_ is the gas limit for initiating the switchboard.
     * @param executionOverhead_ is the overhead for executing the switchboard.
     * @param checkpointManager_ is the address of the checkpoint manager contract.
     * @param fxRoot_ is the address of the root contract.
     * @param owner_ is the address of the contract owner.
     * @param socket_ is the address of the Socket contract.
     * @param gasPriceOracle_ is the address of the gas price oracle contract.
     */
    constructor(
        uint32 chainSlug_,
        uint256 initiateGasLimit_,
        uint256 executionOverhead_,
        address checkpointManager_,
        address fxRoot_,
        address owner_,
        address socket_,
        IGasPriceOracle gasPriceOracle_,
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
        FxBaseRootTunnel(checkpointManager_, fxRoot_)
    {}

    /**
     * @dev Initiates a native confirmation by encoding and sending a message to the child chain.
     * @param packetId_ The packet ID to be confirmed.
     */
    function initiateNativeConfirmation(bytes32 packetId_) external payable {
        bytes memory data = _encodeRemoteCall(packetId_);
        _sendMessageToChild(data);
        emit InitiatedNativeConfirmation(packetId_);
    }

    /**
     * @dev Internal function to encode the remote call.
     * @param packetId_ The packet ID to encode.
     * @return data The encoded data.
     */
    function _encodeRemoteCall(
        bytes32 packetId_
    ) internal view returns (bytes memory data) {
        data = abi.encode(packetId_, _getRoot(packetId_));
    }

    /**
     * @notice The _processMessageFromChild function is an internal function that processes a
     *          message received from a child contract.decodes the message to extract the packetId and root values
     *          and stores them in the packetIdToRoot mapping.
     * @param message_ The message received from the child contract.
     */
    function _processMessageFromChild(bytes memory message_) internal override {
        (bytes32 packetId, bytes32 root) = abi.decode(
            message_,
            (bytes32, bytes32)
        );
        packetIdToRoot[packetId] = root;
        emit RootReceived(packetId, root);
    }

    /**
     * @dev Calculates the minimum fees required for the switchboard to process a request.
     * @param sourceGasPrice_ the gas price for the source chain transaction
     * @return minFees minimum fees required in native token
     */
    function _getMinSwitchboardFees(
        uint32,
        uint256,
        uint256 sourceGasPrice_
    ) internal view override returns (uint256) {
        return initiateGasLimit * sourceGasPrice_;
    }

    /**
     * @notice Set the fxChildTunnel address if not set already.
     * @param fxChildTunnel_ The new fxChildTunnel address to set.
     * @dev The caller must have the GOVERNANCE_ROLE role.
     */
    function setFxChildTunnel(
        address fxChildTunnel_
    ) public override onlyRole(GOVERNANCE_ROLE) {
        emit FxChildTunnelSet(fxChildTunnel, fxChildTunnel_);
        fxChildTunnel = fxChildTunnel_;
    }
}

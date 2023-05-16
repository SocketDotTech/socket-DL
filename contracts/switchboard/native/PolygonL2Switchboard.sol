// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "fx-portal/tunnel/FxBaseChildTunnel.sol";
import "./NativeSwitchboardBase.sol";

/**
 * @title Polygon L2 Switchboard
 * @dev The Polygon L2 Switchboard contract facilitates the bridging
 *    of tokens and messages between the Polygon L1 and L2 networks.
 *    It inherits from the NativeSwitchboardBase and FxBaseChildTunnel contracts.
 */
contract PolygonL2Switchboard is NativeSwitchboardBase, FxBaseChildTunnel {
    /**
     * @dev Event emitted when the fxChildTunnel address is updated.
     * @param oldFxChild The old fxChildTunnel address.
     * @param newFxChild The new fxChildTunnel address.
     */
    event FxChildUpdate(address oldFxChild, address newFxChild);

    /**
     * @dev Event emitted when the fxRootTunnel address is updated.
     * @param fxRootTunnel The fxRootTunnel address.
     * @param newFxRootTunnel The new fxRootTunnel address.
     */
    event FxRootTunnelSet(address fxRootTunnel, address newFxRootTunnel);

    /**
     * @dev Modifier that restricts access to the onlyRemoteSwitchboard.
     * This modifier is inherited from the NativeSwitchboardBase contract.
     */
    modifier onlyRemoteSwitchboard() override {
        revert("ONLY_FX_CHILD");

        _;
    }

    /**
     * @dev Constructor for the PolygonL2Switchboard contract.
     * @param chainSlug_ The chainSlug for the contract.
     * @param initiateGasLimit_ The initiateGasLimit for the contract.
     * @param fxChild_ The address of the fxChildTunnel contract.
     * @param owner_ The owner of the contract.
     * @param socket_ The socket address.
     * @param gasPriceOracle_ The gas price oracle address.
     */
    constructor(
        uint32 chainSlug_,
        uint256 initiateGasLimit_,
        address fxChild_,
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
            gasPriceOracle_,
            signatureVerifier_
        )
        FxBaseChildTunnel(fxChild_)
    {}

    /**
     * @dev Sends a message to the root chain to initiate a native confirmation with the given packet ID.
     * @param packetId_ The packet ID for which the native confirmation needs to be initiated.
     */
    function initiateNativeConfirmation(bytes32 packetId_) external payable {
        bytes memory data = _encodeRemoteCall(packetId_);

        _sendMessageToRoot(data);
        emit InitiatedNativeConfirmation(packetId_);
    }

    /**
     * @dev Encodes the remote call to be sent to the root chain to initiate a native confirmation.
     * @param packetId_ The packet ID for which the native confirmation needs to be initiated.
     * @return data encoded remote call data.
     */
    function _encodeRemoteCall(
        bytes32 packetId_
    ) internal view returns (bytes memory data) {
        data = abi.encode(packetId_, _getRoot(packetId_));
    }

    /**
     * @notice This function processes the message received from the Root contract.
     * @dev decodes the data received and stores the packetId and root in packetIdToRoot mapping.
     *       emits a RootReceived event to indicate that a new root has been received.
     * @param rootMessageSender_ The address of the Root contract that sent the message.
     * @param data_ The data received from the Root contract.
     */
    function _processMessageFromRoot(
        uint256,
        address rootMessageSender_,
        bytes memory data_
    ) internal override validateSender(rootMessageSender_) {
        (bytes32 packetId, bytes32 root) = abi.decode(
            data_,
            (bytes32, bytes32)
        );
        packetIdToRoot[packetId] = root;
        emit RootReceived(packetId, root);
    }

    /**
     * @notice Update the address of the FxChild
     * @param fxChild_ The address of the new FxChild
     **/
    function updateFxChild(
        address fxChild_
    ) external onlyRole(GOVERNANCE_ROLE) {
        emit FxChildUpdate(fxChild, fxChild_);
        fxChild = fxChild_;
    }

    /**
     * @notice setFxRootTunnel is a function in the PolygonL2Switchboard contract that allows the contract owner to set the address of the root tunnel contract on the Ethereum mainnet.
     * @dev This function can only be called by an address with the GOVERNANCE_ROLE role.
     * @param fxRootTunnel_ The address of the root tunnel contract on the Ethereum mainnet.
     */
    function setFxRootTunnel(
        address fxRootTunnel_
    ) external override onlyRole(GOVERNANCE_ROLE) {
        emit FxRootTunnelSet(fxRootTunnel, fxRootTunnel_);
        fxRootTunnel = fxRootTunnel_;
    }
}

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
     * @dev The confirmGasLimit for the contract.
     */
    uint256 public confirmGasLimit;

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
     * @dev Event emitted when the confirmGasLimit is updated.
     * @param confirmGasLimit The new confirmGasLimit value.
     */
    event UpdatedConfirmGasLimit(uint256 confirmGasLimit);

    /**
     * @dev Modifier that restricts access to the onlyRemoteSwitchboard.
     * This modifier is inherited from the NativeSwitchboardBase contract.
     */
    modifier onlyRemoteSwitchboard() override {
        require(false, "ONLY_FX_CHILD");

        _;
    }

    /**
     * @dev Constructor for the PolygonL2Switchboard contract.
     * @param chainSlug_ The chainSlug for the contract.
     * @param confirmGasLimit_ The confirmGasLimit for the contract.
     * @param initiateGasLimit_ The initiateGasLimit for the contract.
     * @param executionOverhead_ The executionOverhead for the contract.
     * @param fxChild_ The address of the fxChildTunnel contract.
     * @param owner_ The owner of the contract.
     * @param socket_ The socket address.
     * @param gasPriceOracle_ The gas price oracle address.
     */
    constructor(
        uint32 chainSlug_,
        uint256 confirmGasLimit_,
        uint256 initiateGasLimit_,
        uint256 executionOverhead_,
        address fxChild_,
        address owner_,
        address socket_,
        IGasPriceOracle gasPriceOracle_
    )
        AccessControl(owner_)
        NativeSwitchboardBase(
            socket_,
            chainSlug_,
            initiateGasLimit_,
            executionOverhead_,
            gasPriceOracle_
        )
        FxBaseChildTunnel(fxChild_)
    {
        confirmGasLimit = confirmGasLimit_;
    }

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
     * @notice This function calculates the minimum fees required to forward a message from the child to the parent chain.
     *  @dev takes as input the dstRelativeGasPrice_ which is the gas price on the destination chain (L1 in this case)
     *       relative to the source chain (L2) and the sourceGasPrice_ which is the gas price
     *       on the source chain (L2 in this case).
     *       function returns the sum of the fees required to initiate the message on the child chain and the
     *       fees required to confirm the message on the parent chain.
     * @param dstRelativeGasPrice_ relativeGasPrice with respect to destintionChain
     * @param sourceGasPrice_ gasPrice on the sourceChainSlug
     * @return minSwitchboardFees minFees
     */
    function _getMinSwitchboardFees(
        uint32,
        uint256 dstRelativeGasPrice_,
        uint256 sourceGasPrice_
    ) internal view override returns (uint256) {
        return
            initiateGasLimit *
            sourceGasPrice_ +
            confirmGasLimit *
            dstRelativeGasPrice_;
    }

    /**
     * @dev Updates the confirmGasLimit parameter of the contract.
     *    This function can only be called by an address with GAS_LIMIT_UPDATER_ROLE.
     *    The function checks that the signature is valid and recovers the signer's address from the signature.
     *    It also checks that the nonce in the signature matches the nonce stored for the signer.
     *   throws if the caller does not have GAS_LIMIT_UPDATER_ROLE.
     *   throws {InvalidNonce} If the nonce provided in the signature does not match the nonce stored for the signer.
     * @param nonce_ The nonce provided in the signature.
     * @param confirmGasLimit_ The new value of the confirmGasLimit parameter.
     * @param signature_ The signature used to authenticate the transaction.
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

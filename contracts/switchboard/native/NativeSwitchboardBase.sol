// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../../interfaces/ISocket.sol";
import "../../interfaces/ISwitchboard.sol";
import "../../interfaces/ICapacitor.sol";
import "../../interfaces/ISignatureVerifier.sol";
import "../../interfaces/IExecutionManager.sol";
import "../../libraries/RescueFundsLib.sol";
import "../../utils/AccessControlExtended.sol";

import {GOVERNANCE_ROLE, RESCUE_ROLE, WITHDRAW_ROLE, TRIP_ROLE, UN_TRIP_ROLE, FEES_UPDATER_ROLE} from "../../utils/AccessRoles.sol";
import {TRIP_NATIVE_SIG_IDENTIFIER, UN_TRIP_NATIVE_SIG_IDENTIFIER, FEES_UPDATE_SIG_IDENTIFIER} from "../../utils/SigIdentifiers.sol";

/**
@title Native Switchboard Base Contract
@notice This contract serves as the base for the implementation of a switchboard for native cross-chain communication.
It provides the necessary functionalities to allow packets to be sent and received between chains and ensures proper handling
of fees, gas limits, and packet validation.
@dev This contract has access-controlled functions and connects to a capacitor contract that holds packets for the native bridge.
*/
abstract contract NativeSwitchboardBase is ISwitchboard, AccessControlExtended {
    ISignatureVerifier public immutable signatureVerifier__;
    ISocket public immutable socket__;
    ICapacitor public capacitor__;
    uint32 public immutable chainSlug;

    /**
     * @dev Flag that indicates if the global fuse is tripped, meaning no more packets can be sent.
     */
    bool public isGlobalTipped;

    /**
     * @dev Flag that indicates if the switchboard is registered and its capacitor has been assigned.
     */
    bool public isInitialized;

    // This is to prevent attacks with sending messages for chain before the switchboard is registered for them.
    uint256 initialPacketCount;

    /**
     * @dev Address of the remote native switchboard.
     */
    address public remoteNativeSwitchboard;

    // Per packet fees used to compensate operator to send packets via native bridge.
    uint128 public switchboardFees;

    // Per message fees paid to executor for verification overhead.
    uint128 public verificationOverheadFees;

    /**
     * @dev Stores the roots received from native bridge.
     */
    mapping(bytes32 => bytes32) public packetIdToRoot;

    /**
     * @dev incrementing nonce used for signatures of fee updater, tripper, untripper
     */
    mapping(address => uint256) public nextNonce;

    /**
     * @dev Event emitted when the switchboard trip status changes
     */
    event GlobalTripChanged(bool isGlobalTipped);

    /**
     * @dev This event is emitted when this switchboard wants to connect with its sibling on other chain.
     * @param remoteNativeSwitchboard address of switchboard on sibling chain.
     */
    event UpdatedRemoteNativeSwitchboard(address remoteNativeSwitchboard);

    /**
     * @dev Event emitted when a packet root relay via native bridge is initialised
     * @param packetId The packet ID.
     */
    event InitiatedNativeConfirmation(bytes32 packetId);

    /**
     * @dev Event emitted when a root is received via native bridge.
     * @param packetId The unique identifier of the packet.
     * @param root The root hash of the packet.
     */
    event RootReceived(bytes32 packetId, bytes32 root);

    /**
     * @dev Emitted when a fees is set for switchboard
     * @param switchboardFees switchboardFees
     * @param verificationOverheadFees verificationOverheadFees
     */
    event SwitchboardFeesSet(
        uint256 switchboardFees,
        uint256 verificationOverheadFees
    );

    /**
     * @dev Error thrown when the fees provided are not enough to execute the transaction.
     */
    error FeesNotEnough();

    /**
     * @dev Error thrown when the contract has already been initialized.
     */
    error AlreadyInitialized();

    /**
     * @dev Error thrown when the root receive transaction is not sent by a valid sender. i.e. native bridge contract
     */
    error InvalidSender();

    /**
     * @dev Error thrown when a root hash cannot be found for the given packet ID.
     */
    error NoRootFound();

    /**
     * @dev Error thrown when the nonce of the signature is invalid.
     */
    error InvalidNonce();

    // Error thrown if fees are received from non execution manager.
    error OnlyExecutionManager();

    /**
     * @dev Modifier to ensure that a function can only be called by the remote switchboard.
     */
    modifier onlyRemoteSwitchboard() virtual;

    /**
     * @dev Constructor function for the Native switchboard contract.
     * @param socket_ The address of socket.
     * @param chainSlug_ The identifier of the chain the contract is deployed on.
     * @param signatureVerifier_ signatureVerifier instance
     */
    constructor(
        address socket_,
        uint32 chainSlug_,
        ISignatureVerifier signatureVerifier_
    ) {
        socket__ = ISocket(socket_);
        chainSlug = chainSlug_;
        signatureVerifier__ = signatureVerifier_;
    }

    /**
     * @notice retrieves the root for a given packet ID from capacitor
     * @param packetId_ packet ID
     * @return root root associated with the given packet ID
     * @dev Reverts with 'NoRootFound' error if no root is found for the given packet ID
     */
    function _getRoot(bytes32 packetId_) internal view returns (bytes32 root) {
        uint64 capacitorPacketCount = uint64(uint256(packetId_));
        root = capacitor__.getRootByCount(capacitorPacketCount);
        if (root == bytes32(0)) revert NoRootFound();
    }

    /**
     * @notice records the root for a given packet ID sent by a remote switchboard via native bridge
     * @dev this function is not used by polygon native bridge, it works by calling a different function.
     * @param packetId_ packet ID
     * @param root_ root for the given packet ID
     */
    function receivePacket(
        bytes32 packetId_,
        bytes32 root_
    ) external onlyRemoteSwitchboard {
        packetIdToRoot[packetId_] = root_;
        emit RootReceived(packetId_, root_);
    }

    /**
     * @inheritdoc ISwitchboard
     */
    function allowPacket(
        bytes32 root_,
        bytes32 packetId_,
        uint256,
        uint32,
        uint256
    ) external view override returns (bool) {
        uint64 packetCount = uint64(uint256(packetId_));

        if (isGlobalTipped) return false;
        if (packetCount < initialPacketCount) return false;
        if (packetIdToRoot[packetId_] != root_) return false;

        return true;
    }

    /**
     * @dev Get the minimum fees for a cross-chain transaction.
     * @return switchboardFee_ The fee charged by the switchboard for the transaction.
     * @return verificationFee_ The fee charged by the verifier for the transaction.
     */
    function getMinFees(
        uint32
    )
        external
        view
        override
        returns (uint128 switchboardFee_, uint128 verificationFee_)
    {
        return (switchboardFees, verificationOverheadFees);
    }

    /**
     * @inheritdoc ISwitchboard
     */
    function setFees(
        uint256 nonce_,
        uint32,
        uint128 switchboardFees_,
        uint128 verificationOverheadFees_,
        bytes calldata signature_
    ) external override {
        address feesUpdater = signatureVerifier__.recoverSigner(
            keccak256(
                abi.encode(
                    FEES_UPDATE_SIG_IDENTIFIER,
                    address(this),
                    chainSlug,
                    nonce_,
                    switchboardFees_,
                    verificationOverheadFees_
                )
            ),
            signature_
        );

        _checkRole(FEES_UPDATER_ROLE, feesUpdater);
        // Nonce is used by gated roles and we don't expect nonce to reach the max value of uint256
        unchecked {
            if (nonce_ != nextNonce[feesUpdater]++) revert InvalidNonce();
        }
        switchboardFees = switchboardFees_;
        verificationOverheadFees = verificationOverheadFees_;

        emit SwitchboardFeesSet(switchboardFees, verificationOverheadFees);
    }

    /**
     * @inheritdoc ISwitchboard
     */
    function registerSiblingSlug(
        uint32 siblingChainSlug_,
        uint256 maxPacketLength_,
        uint256 capacitorType_,
        uint256 initialPacketCount_,
        address remoteNativeSwitchboard_
    ) external override onlyRole(GOVERNANCE_ROLE) {
        if (isInitialized) revert AlreadyInitialized();

        initialPacketCount = initialPacketCount_;
        (address capacitor, ) = socket__.registerSwitchboardForSibling(
            siblingChainSlug_,
            maxPacketLength_,
            capacitorType_,
            remoteNativeSwitchboard_
        );

        isInitialized = true;
        capacitor__ = ICapacitor(capacitor);
        remoteNativeSwitchboard = remoteNativeSwitchboard_;
    }

    /**
     * @notice Updates the sibling switchboard for given `siblingChainSlug_`.
     * @dev This function is expected to be only called by admin
     * @param siblingChainSlug_ The slug of the sibling chain to register switchboard with.
     * @param remoteNativeSwitchboard_ The switchboard address deployed on `siblingChainSlug_`
     */
    function updateSibling(
        uint32 siblingChainSlug_,
        address remoteNativeSwitchboard_
    ) external onlyRole(GOVERNANCE_ROLE) {
        // signal to socket
        socket__.useSiblingSwitchboard(
            siblingChainSlug_,
            remoteNativeSwitchboard_
        );

        // use address while relaying via native bridge
        remoteNativeSwitchboard = remoteNativeSwitchboard_;
        emit UpdatedRemoteNativeSwitchboard(remoteNativeSwitchboard_);
    }

    /**
     * @notice Allows to trip the global fuse and prevent the switchboard to process packets
     * @dev The function recovers the signer from the given signature and verifies if the signer has the TRIP_ROLE.
     *      The nonce must be equal to the next nonce of the caller. If the caller doesn't have the TRIP_ROLE or the nonce
     *      is incorrect, it will revert.
     *       Once the function is successful, the isGlobalTipped variable is set to true and the GlobalTripChanged event is emitted.
     * @param nonce_ The nonce of the caller.
     * @param signature_ The signature of the message
     */
    function tripGlobal(uint256 nonce_, bytes memory signature_) external {
        address tripper = signatureVerifier__.recoverSigner(
            // it includes trip status at the end
            keccak256(
                abi.encode(
                    TRIP_NATIVE_SIG_IDENTIFIER,
                    address(this),
                    chainSlug,
                    nonce_,
                    true
                )
            ),
            signature_
        );

        _checkRole(TRIP_ROLE, tripper);
        // Nonce is used by gated roles and we don't expect nonce to reach the max value of uint256
        unchecked {
            if (nonce_ != nextNonce[tripper]++) revert InvalidNonce();
        }
        isGlobalTipped = true;
        emit GlobalTripChanged(true);
    }

    /**
     * @notice Allows a untripper to un trip the switchboard by providing a signature and a nonce.
     * @dev To un trip, the untripper must have the UN_TRIP_ROLE.
     * @param nonce_ The nonce to prevent replay attacks.
     * @param signature_ The signature created by the untripper.
     */
    function unTrip(uint256 nonce_, bytes memory signature_) external {
        address untripper = signatureVerifier__.recoverSigner(
            // it includes trip status at the end
            keccak256(
                abi.encode(
                    UN_TRIP_NATIVE_SIG_IDENTIFIER,
                    address(this),
                    chainSlug,
                    nonce_,
                    false
                )
            ),
            signature_
        );

        _checkRole(UN_TRIP_ROLE, untripper);

        // Nonce is used by gated roles and we don't expect nonce to reach the max value of uint256
        unchecked {
            if (nonce_ != nextNonce[untripper]++) revert InvalidNonce();
        }
        isGlobalTipped = false;
        emit GlobalTripChanged(false);
    }

    /**
     * @notice Allows the withdrawal of fees by the account with the specified address.
     * @param withdrawTo_ The address of the account to withdraw fees to.
     * @dev The caller must have the WITHDRAW_ROLE.
     */
    function withdrawFees(
        address withdrawTo_
    ) external onlyRole(WITHDRAW_ROLE) {
        if (withdrawTo_ == address(0)) revert ZeroAddress();
        SafeTransferLib.safeTransferETH(withdrawTo_, address(this).balance);
    }

    /**
     * @notice Rescues funds from the contract if they are locked by mistake.
     * @param token_ The address of the token contract.
     * @param rescueTo_ The address where rescued tokens need to be sent.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(
        address token_,
        address rescueTo_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, rescueTo_, amount_);
    }

    /**
     * @inheritdoc ISwitchboard
     */
    function receiveFees(uint32) external payable override {
        if (msg.sender != address(socket__.executionManager__()))
            revert OnlyExecutionManager();
    }
}

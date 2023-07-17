// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../../interfaces/ISocket.sol";
import "../../interfaces/ISwitchboard.sol";
import "../../interfaces/ISignatureVerifier.sol";
import "../../utils/AccessControlExtended.sol";
import "../../libraries/RescueFundsLib.sol";

import {GOVERNANCE_ROLE, WITHDRAW_ROLE, RESCUE_ROLE, TRIP_ROLE, UN_TRIP_ROLE, WATCHER_ROLE, FEES_UPDATER_ROLE} from "../../utils/AccessRoles.sol";
import {TRIP_PATH_SIG_IDENTIFIER, TRIP_GLOBAL_SIG_IDENTIFIER, TRIP_PROPOSAL_SIG_IDENTIFIER, UN_TRIP_PATH_SIG_IDENTIFIER, UN_TRIP_GLOBAL_SIG_IDENTIFIER, FEES_UPDATE_SIG_IDENTIFIER} from "../../utils/SigIdentifiers.sol";

abstract contract SwitchboardBase is ISwitchboard, AccessControlExtended {
    // signature verifier contract
    ISignatureVerifier public immutable signatureVerifier__;

    // socket contract
    ISocket public immutable socket__;

    // chain slug of deployed chain
    uint32 public immutable chainSlug;

    // timeout after which packets become valid
    // optimistic switchboard: this is the wait time to validate packet
    // fast switchboard: this makes packets valid even if all watchers have not attested
    //      used to make the system work when watchers are inactive due to infra etc problems
    // this is only applicable if none of the trips are triggered
    uint256 public immutable timeoutInSeconds;

    // variable to pause the switchboard completely, to be used only in case of smart contract bug
    // trip can be done by TRIP_ROLE holders
    // untrip can be done by UN_TRIP_ROLE holders
    bool public isGlobalTipped;

    // pause all proposals coming from given chain.
    // to be used if a transmitter has gone rogue and needs to be kicked to resume normal functioning
    // trip can be done by WATCHER_ROLE holders
    // untrip can be done by UN_TRIP_ROLE holders
    // sourceChain => isPaused
    mapping(uint32 => bool) public isPathTripped;

    // block execution of single proposal
    // to be used if transmitter proposes wrong packet root single time
    // trip can be done by WATCHER_ROLE holders
    // untrip not possible, but same root can be proposed again at next proposalCount
    // isProposalTripped(packetId => proposalCount => isTripped)
    mapping(bytes32 => mapping(uint256 => bool)) public isProposalTripped;

    // incrementing nonce for each signer
    // watcher => nextNonce
    mapping(address => uint256) public nextNonce;

    struct Fees {
        uint128 switchboardFees; // Fees paid to Switchboard per packet
        uint128 verificationOverheadFees; // Fees paid to executor per message
    }
    // destinationChainSlug => fees-struct with verificationOverheadFees and switchboardFees
    mapping(uint32 => Fees) public fees;

    // destinationChainSlug => initialPacketCount - packets with packetCount after this will be accepted at the switchboard.
    // This is to prevent attacks with sending messages for chain slugs before the switchboard is registered for them.
    mapping(uint32 => uint256) public initialPacketCount;

    /**
     * @dev Emitted when global trip status changes
     * @param isGlobalTipped New trip status of the contract
     */
    event GlobalTripChanged(bool isGlobalTipped);

    /**
     * @dev Emitted when path trip status changes
     * @param srcChainSlug Chain slug of the source chain
     * @param isPathTripped New trip status of the path
     */
    event PathTripChanged(uint32 srcChainSlug, bool isPathTripped);

    /**
     * @dev Emitted when a proposal for a packetId is tripped
     * @param packetId packetId of packet
     * @param proposalCount proposalCount being tripped
     */
    event ProposalTripped(bytes32 packetId, uint256 proposalCount);

    /**
     * @dev Emitted when a fees is set for switchboard
     * @param siblingChainSlug Chain slug of the sibling chain
     * @param fees Fees struct with verificationOverheadFees and switchboardFees
     */
    event SwitchboardFeesSet(uint32 siblingChainSlug, Fees fees);

    // Error hit when a signature with unexpected nonce is received
    error InvalidNonce();

    // Error hit when tx from invalid ExecutionManager is received
    error OnlyExecutionManager();

    /**
     * @dev Constructor of SwitchboardBase
     * @param socket_ Address of the socket contract
     * @param chainSlug_ Chain slug of deployment chain
     * @param timeoutInSeconds_ Time after which proposals become valid if not tripped
     * @param signatureVerifier_ signatureVerifier_ contract
     */
    constructor(
        address socket_,
        uint32 chainSlug_,
        uint256 timeoutInSeconds_,
        ISignatureVerifier signatureVerifier_
    ) {
        socket__ = ISocket(socket_);
        chainSlug = chainSlug_;
        timeoutInSeconds = timeoutInSeconds_;
        signatureVerifier__ = signatureVerifier_;
    }

    /**
     * @inheritdoc ISwitchboard
     */
    function getMinFees(
        uint32 dstChainSlug_
    ) external view override returns (uint128, uint128) {
        Fees memory minFees = fees[dstChainSlug_];
        return (minFees.switchboardFees, minFees.verificationOverheadFees);
    }

    /**
     * @inheritdoc ISwitchboard
     */
    function registerSiblingSlug(
        uint32 siblingChainSlug_,
        uint256 maxPacketLength_,
        uint256 capacitorType_,
        uint256 initialPacketCount_,
        address siblingSwitchboard_
    ) external override onlyRole(GOVERNANCE_ROLE) {
        initialPacketCount[siblingChainSlug_] = initialPacketCount_;

        socket__.registerSwitchboardForSibling(
            siblingChainSlug_,
            maxPacketLength_,
            capacitorType_,
            siblingSwitchboard_
        );
    }

    /**
     * @notice Signals sibling switchboard for given `siblingChainSlug_`.
     * @dev This function is expected to be only called by governance
     * @param siblingChainSlug_ The slug of the sibling chain whos switchboard is being connected.
     * @param siblingSwitchboard_ The switchboard address deployed on `siblingChainSlug_`
     */
    function updateSibling(
        uint32 siblingChainSlug_,
        address siblingSwitchboard_
    ) external onlyRole(GOVERNANCE_ROLE) {
        socket__.useSiblingSwitchboard(siblingChainSlug_, siblingSwitchboard_);
    }

    /**
     * @notice Pauses this switchboard completely. To be used in case of contract bug.
     * @param nonce_ The nonce used for signature.
     * @param signature_ The signature provided to validate the trip.
     */
    function tripGlobal(uint256 nonce_, bytes memory signature_) external {
        address tripper = signatureVerifier__.recoverSigner(
            // it includes trip status at the end
            keccak256(
                abi.encode(
                    TRIP_GLOBAL_SIG_IDENTIFIER,
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
     * @notice Pauses a path. To be used when a transmitter goes rogue and needs to be kicked.
     * @param nonce_ The nonce used for signature.
     * @param srcChainSlug_ The source chain slug of the path to be paused.
     * @param signature_ The signature provided to validate the trip.
     */
    function tripPath(
        uint256 nonce_,
        uint32 srcChainSlug_,
        bytes memory signature_
    ) external {
        address watcher = signatureVerifier__.recoverSigner(
            // it includes trip status at the end
            keccak256(
                abi.encode(
                    TRIP_PATH_SIG_IDENTIFIER,
                    address(this),
                    srcChainSlug_,
                    chainSlug,
                    nonce_,
                    true
                )
            ),
            signature_
        );

        _checkRoleWithSlug(WATCHER_ROLE, srcChainSlug_, watcher);

        // Nonce is used by gated roles and we don't expect nonce to reach the max value of uint256
        unchecked {
            if (nonce_ != nextNonce[watcher]++) revert InvalidNonce();
        }
        //source chain based tripping
        isPathTripped[srcChainSlug_] = true;
        emit PathTripChanged(srcChainSlug_, true);
    }

    /**
     * @notice Pauses a particular proposal of a packet. To be used if transmitter proposes wrong root.
     * @param nonce_ The nonce used for signature.
     * @param packetId_ The ID of the packet.
     * @param proposalCount_ The count of the proposal to be paused.
     * @param signature_ The signature provided to validate the trip.
     */
    function tripProposal(
        uint256 nonce_,
        bytes32 packetId_,
        uint256 proposalCount_,
        bytes memory signature_
    ) external {
        uint32 srcChainSlug = uint32(uint256(packetId_) >> 224);
        address watcher = signatureVerifier__.recoverSigner(
            keccak256(
                abi.encode(
                    TRIP_PROPOSAL_SIG_IDENTIFIER,
                    address(this),
                    srcChainSlug,
                    chainSlug,
                    nonce_,
                    packetId_,
                    proposalCount_
                )
            ),
            signature_
        );

        _checkRoleWithSlug(WATCHER_ROLE, srcChainSlug, watcher);
        // Nonce is used by gated roles and we don't expect nonce to reach the max value of uint256
        unchecked {
            if (nonce_ != nextNonce[watcher]++) revert InvalidNonce();
        }

        isProposalTripped[packetId_][proposalCount_] = true;
        emit ProposalTripped(packetId_, proposalCount_);
    }

    /**
     * @notice Unpauses a path. To be used after bad transmitter has been kicked from system.
     * @param nonce_ The nonce used for the signature.
     * @param srcChainSlug_ The source chain slug of the path to be unpaused.
     * @param signature_ The signature provided to validate the un trip.
     */
    function unTripPath(
        uint256 nonce_,
        uint32 srcChainSlug_,
        bytes memory signature_
    ) external {
        address unTripper = signatureVerifier__.recoverSigner(
            // it includes trip status at the end
            keccak256(
                abi.encode(
                    UN_TRIP_PATH_SIG_IDENTIFIER,
                    address(this),
                    srcChainSlug_,
                    chainSlug,
                    nonce_,
                    false
                )
            ),
            signature_
        );

        _checkRole(UN_TRIP_ROLE, unTripper);
        // Nonce is used by gated roles and we don't expect nonce to reach the max value of uint256
        unchecked {
            if (nonce_ != nextNonce[unTripper]++) revert InvalidNonce();
        }
        isPathTripped[srcChainSlug_] = false;
        emit PathTripChanged(srcChainSlug_, false);
    }

    /**
     * @notice Unpauses global execution. To be used if contract bug is addressed.
     * @param nonce_ The nonce used for the signature.
     * @param signature_ The signature provided to validate the un trip.
     */
    function unTrip(uint256 nonce_, bytes memory signature_) external {
        address unTripper = signatureVerifier__.recoverSigner(
            // it includes trip status at the end
            keccak256(
                abi.encode(
                    UN_TRIP_GLOBAL_SIG_IDENTIFIER,
                    address(this),
                    chainSlug,
                    nonce_,
                    false
                )
            ),
            signature_
        );

        _checkRole(UN_TRIP_ROLE, unTripper);

        // Nonce is used by gated roles and we don't expect nonce to reach the max value of uint256
        unchecked {
            if (nonce_ != nextNonce[unTripper]++) revert InvalidNonce();
        }
        isGlobalTipped = false;
        emit GlobalTripChanged(false);
    }

    /**
     * @notice Withdraw fees from the contract to an account.
     * @param withdrawTo_ The address where we should send the fees.
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
     * @dev Receiving only allowed from execution manager
     * @dev Need to receive fees before change in case execution manager
     *      is being updated on socket.
     */
    function receiveFees(uint32) external payable override {
        if (msg.sender != address(socket__.executionManager__()))
            revert OnlyExecutionManager();
    }
}

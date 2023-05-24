// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../../interfaces/ISwitchboard.sol";
import "../../interfaces/ISignatureVerifier.sol";
import "../../utils/AccessControlExtended.sol";

import "../../libraries/SignatureVerifierLib.sol";
import "../../libraries/RescueFundsLib.sol";
import "../../libraries/FeesHelper.sol";

import {GOVERNANCE_ROLE, WITHDRAW_ROLE, RESCUE_ROLE, TRIP_ROLE, UNTRIP_ROLE, WATCHER_ROLE, FEES_UPDATER_ROLE} from "../../utils/AccessRoles.sol";
import {TRIP_PATH_SIG_IDENTIFIER, TRIP_GLOBAL_SIG_IDENTIFIER, UNTRIP_PATH_SIG_IDENTIFIER, UNTRIP_GLOBAL_SIG_IDENTIFIER, FEES_UPDATE_SIG_IDENTIFIER} from "../../utils/SigIdentifiers.sol";

abstract contract SwitchboardBase is ISwitchboard, AccessControlExtended {
    ISignatureVerifier public immutable signatureVerifier__;

    bool public tripGlobalFuse;
    address public immutable socket;
    uint32 public immutable chainSlug;
    uint256 public immutable timeoutInSeconds;

    struct Fees {
        uint256 switchboardFees;
        uint256 verificationFees;
    }

    mapping(uint32 => bool) public isInitialised;
    mapping(uint32 => uint256) public maxPacketSize;

    // sourceChain => isPaused
    mapping(uint32 => bool) public tripSinglePath;

    // watcher => nextNonce
    mapping(address => uint256) public nextNonce;

    // destinationChainSlug => fees-struct with verificationFees and switchboardFees
    mapping(uint32 => Fees) public fees;

    /**
     * @dev Emitted when a path is tripped
     * @param srcChainSlug Chain slug of the source chain
     * @param tripSinglePath New trip status of the path
     */
    event PathTripped(uint32 srcChainSlug, bool tripSinglePath);
    /**
     * @dev Emitted when Switchboard contract is tripped globally
     * @param tripGlobalFuse New trip status of the contract
     */
    event SwitchboardTripped(bool tripGlobalFuse);
    /**
     * @dev Emitted when execution overhead is set for a destination chain
     * @param dstChainSlug Chain slug of the destination chain
     * @param executionOverhead New execution overhead
     */
    event ExecutionOverheadSet(uint32 dstChainSlug, uint256 executionOverhead);

    /**
     * @dev Emitted when a capacitor is registered
     * @param siblingChainSlug Chain slug of the sibling chain
     * @param capacitor Address of the capacitor
     * @param maxPacketSize Maximum number of messages in one packet
     */
    event CapacitorRegistered(
        uint32 siblingChainSlug,
        address capacitor,
        uint256 maxPacketSize
    );

    /**
     * @dev Emitted when a fees is set for switchboard
     * @param siblingChainSlug Chain slug of the sibling chain
     * @param fees fees struct with verificationFees and switchboardFees
     */
    event SwitchboardFeesSet(uint32 siblingChainSlug, Fees fees);

    error AlreadyInitialised();
    error InvalidNonce();
    error OnlySocket();

    /**
     * @dev Constructor of SwitchboardBase
     * @param socket_ Address of the socket contract
     * @param chainSlug_ Chain slug of the contract
     * @param timeoutInSeconds_ Timeout duration of the transactions
     */
    constructor(
        address socket_,
        uint32 chainSlug_,
        uint256 timeoutInSeconds_,
        ISignatureVerifier signatureVerifier_
    ) {
        socket = socket_;
        chainSlug = chainSlug_;
        timeoutInSeconds = timeoutInSeconds_;
        signatureVerifier__ = signatureVerifier_;
    }

    /**
     * @inheritdoc ISwitchboard
     */
    function payFees(uint32 dstChainSlug_) external payable override {}

    /**
     * @inheritdoc ISwitchboard
     */
    function getMinFees(
        uint32 dstChainSlug_
    ) external view override returns (uint256, uint256) {
        return (
            fees[dstChainSlug_].switchboardFees,
            fees[dstChainSlug_].verificationFees
        );
    }

    /**
     * @notice set capacitor address and packet size
     * @param capacitor_ capacitor address
     * @param maxPacketSize_ max messages allowed in one packet
     */
    function registerCapacitor(
        uint32 siblingChainSlug_,
        address capacitor_,
        uint256 maxPacketSize_
    ) external override {
        if (msg.sender != socket) revert OnlySocket();
        if (isInitialised[siblingChainSlug_]) revert AlreadyInitialised();

        isInitialised[siblingChainSlug_] = true;
        maxPacketSize[siblingChainSlug_] = maxPacketSize_;
        emit CapacitorRegistered(siblingChainSlug_, capacitor_, maxPacketSize_);
    }

    /**
     * @notice pause a path
     */
    function tripPath(
        uint256 nonce_,
        uint32 srcChainSlug_,
        bytes memory signature_
    ) external {
        address watcher = SignatureVerifierLib.recoverSignerFromDigest(
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
        uint256 nonce = nextNonce[watcher]++;
        if (nonce_ != nonce) revert InvalidNonce();

        //source chain based tripping
        tripSinglePath[srcChainSlug_] = true;
        emit PathTripped(srcChainSlug_, true);
    }

    /**
     * @notice pause execution
     */
    function tripGlobal(uint256 nonce_, bytes memory signature_) external {
        address tripper = SignatureVerifierLib.recoverSignerFromDigest(
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
        uint256 nonce = nextNonce[tripper]++;
        if (nonce_ != nonce) revert InvalidNonce();

        tripGlobalFuse = true;
        emit SwitchboardTripped(true);
    }

    /**
     * @notice unpause a path
     */
    function untripPath(
        uint256 nonce_,
        uint32 srcChainSlug_,
        bytes memory signature_
    ) external {
        address untripper = SignatureVerifierLib.recoverSignerFromDigest(
            // it includes trip status at the end
            keccak256(
                abi.encode(
                    UNTRIP_PATH_SIG_IDENTIFIER,
                    address(this),
                    chainSlug,
                    srcChainSlug_,
                    nonce_,
                    false
                )
            ),
            signature_
        );

        _checkRole(UNTRIP_ROLE, untripper);
        uint256 nonce = nextNonce[untripper]++;
        if (nonce_ != nonce) revert InvalidNonce();

        tripSinglePath[srcChainSlug_] = false;
        emit PathTripped(srcChainSlug_, false);
    }

    /**
     * @notice unpause execution
     */
    function untrip(uint256 nonce_, bytes memory signature_) external {
        address untripper = SignatureVerifierLib.recoverSignerFromDigest(
            // it includes trip status at the end
            keccak256(
                abi.encode(
                    UNTRIP_GLOBAL_SIG_IDENTIFIER,
                    address(this),
                    chainSlug,
                    nonce_,
                    false
                )
            ),
            signature_
        );

        _checkRole(UNTRIP_ROLE, untripper);
        uint256 nonce = nextNonce[untripper]++;
        if (nonce_ != nonce) revert InvalidNonce();

        tripGlobalFuse = false;
        emit SwitchboardTripped(false);
    }

    function setFees(
        uint256 nonce_,
        uint32 dstChainSlug_,
        uint256 switchboardFees_,
        uint256 verificationFees_,
        bytes calldata signature_
    ) external override {
        address feesUpdater = signatureVerifier__.recoverSignerFromDigest(
            keccak256(
                abi.encode(
                    FEES_UPDATE_SIG_IDENTIFIER,
                    address(this),
                    chainSlug,
                    dstChainSlug_,
                    nonce_,
                    switchboardFees_,
                    verificationFees_
                )
            ),
            signature_
        );

        _checkRoleWithSlug(FEES_UPDATER_ROLE, dstChainSlug_, feesUpdater);

        uint256 nonce = nextNonce[feesUpdater]++;
        if (nonce_ != nonce) revert InvalidNonce();

        Fees memory feesObject = Fees({
            switchboardFees: switchboardFees_,
            verificationFees: verificationFees_
        });

        fees[dstChainSlug_] = feesObject;

        emit SwitchboardFeesSet(dstChainSlug_, feesObject);
    }

    function withdrawFees(address account_) external onlyRole(WITHDRAW_ROLE) {
        FeesHelper.withdrawFees(account_);
    }

    /**
     * @notice Rescues funds from a contract that has lost access to them.
     * @param token_ The address of the token contract.
     * @param userAddress_ The address of the user who lost access to the funds.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./interfaces/IExecutionManager.sol";
import "./interfaces/ISignatureVerifier.sol";
import "./libraries/RescueFundsLib.sol";
import "./libraries/FeesHelper.sol";
import "./utils/AccessControlExtended.sol";
import {WITHDRAW_ROLE, RESCUE_ROLE, GOVERNANCE_ROLE, EXECUTOR_ROLE, FEES_UPDATER_ROLE} from "./utils/AccessRoles.sol";
import {FEES_UPDATE_SIG_IDENTIFIER, RELATIVE_NATIVE_TOKEN_PRICE_UPDATE_SIG_IDENTIFIER, MSG_VALUE_MAX_THRESHOLD_SIG_IDENTIFIER, MSG_VALUE_MIN_THRESHOLD_SIG_IDENTIFIER} from "./utils/SigIdentifiers.sol";

/**
 * @title ExecutionManager
 * @dev Implementation of the IExecutionManager interface, providing functions for executing cross-chain transactions and
 * managing execution fees. This contract also implements the AccessControl interface, allowing for role-based
 * access control.
 */
contract ExecutionManager is IExecutionManager, AccessControlExtended {
    ISignatureVerifier public immutable signatureVerifier__;

    /**
     * @notice Emitted when the executionFees is updated
     * @param dstChainSlug The destination chain slug for which the executionFees is updated
     * @param executionFees The new executionFees
     */
    event ExecutionFeesSet(uint256 dstChainSlug, uint256 executionFees);

    event RelativeNativeTokenPriceSet(
        uint256 dstChainSlug,
        uint256 relativeNativeTokenPrice
    );

    event MsgValueMaxThresholdSet(
        uint256 dstChainSlug,
        uint256 msgValueMaxThresholdSet
    );
    event MsgValueMinThresholdSet(
        uint256 dstChainSlug,
        uint256 msgValueMinThresholdSet
    );

    uint32 public immutable chainSlug;

    // transmitter => nextNonce
    mapping(address => uint256) public nextNonce;

    // remoteChainSlug => executionFees
    mapping(uint32 => uint256) public executionFees;

    // destSlug => relativeNativePrice (stores (destnativeTokenPriceUSD*(1e18)/srcNativeTokenPriceUSD))
    mapping(uint32 => uint256) public relativeNativeTokenPrice;

    // mapping(uint32 => uint256) public baseGasUsed;

    mapping(uint32 => uint256) public msgValueMinThreshold;

    mapping(uint32 => uint256) public msgValueMaxThreshold;

    // msg.value*scrNativePrice >= relativeNativeTokenPrice[srcSlug][destinationSlug] * destMsgValue /10^18

    error InvalidNonce();
    error MsgValueTooLow();
    error MsgValueTooHigh();
    error PayloadTooLarge();
    error InsufficientMsgValue();

    /**
     * @dev Constructor for ExecutionManager contract
     * @param owner_ Address of the contract owner
     */
    constructor(
        address owner_,
        uint32 chainSlug_,
        ISignatureVerifier signatureVerifier_
    ) AccessControlExtended(owner_) {
        chainSlug = chainSlug_;
        signatureVerifier__ = signatureVerifier_;
    }

    /**
     * @notice Checks whether the provided signer address is an executor for the given packed message and signature
     * @param packedMessage Packed message to be executed
     * @param sig Signature of the message
     * @return executor Address of the executor
     * @return isValidExecutor Boolean value indicating whether the executor is valid or not
     */
    function isExecutor(
        bytes32 packedMessage,
        bytes memory sig
    )
        external
        view
        virtual
        override
        returns (address executor, bool isValidExecutor)
    {
        executor = signatureVerifier__.recoverSignerFromDigest(
            packedMessage,
            sig
        );
        isValidExecutor = _hasRole(EXECUTOR_ROLE, executor);
    }

    /**
     * @dev Function to be used for on-chain fee distribution later
     */
    function updateExecutionFees(address, uint256, bytes32) external override {}

    /**
     * @notice Function for paying fees for cross-chain transaction execution
     * @param msgGasLimit_ Gas limit for the transaction
     * @param siblingChainSlug_ Sibling chain identifier
     */
    function payFees(
        uint256 msgGasLimit_,
        uint32 siblingChainSlug_
    ) external payable override {}

    /**
     * @notice Function for getting the minimum fees required for executing a cross-chain transaction
     * @dev This function is called at source to calculate the execution cost.
     * @param siblingChainSlug_ Sibling chain identifier
     * @param payloadSize_ byte length of payload. Currently only used to check max length, later on will be used for fees calculation.
     * @param extraParams_ Can be used for providing extra information. Currently used for msgValue
     * @return Minimum fees required for executing the transaction
     */
    function getMinFees(
        uint256 gasLimit_,
        uint256 payloadSize_,
        bytes32 extraParams_,
        uint32 siblingChainSlug_
    ) external view override returns (uint256) {
        if (payloadSize_ > 3000) revert PayloadTooLarge();

        uint256 params = uint256(extraParams_);
        uint8 paramType = uint8(params >> 224);

        if (paramType == 0) return executionFees[siblingChainSlug_];

        uint256 msgValue = uint256(uint224(params));

        if (msgValue < msgValueMinThreshold[siblingChainSlug_])
            revert MsgValueTooLow();
        if (msgValue > msgValueMaxThreshold[siblingChainSlug_])
            revert MsgValueTooHigh();

        uint256 msgValueRequiredOnSrcChain = (relativeNativeTokenPrice[
            siblingChainSlug_
        ] * msgValue) / 1e18;
        return msgValueRequiredOnSrcChain + executionFees[siblingChainSlug_];
    }

    function verifyParams(
        bytes32 extraParams_,
        uint256 msgValue_
    ) external pure override {
        uint256 params = uint256(extraParams_);
        uint8 paramType = uint8(params >> 224);

        if (paramType == 0) return;

        uint256 expectedMsgValue = uint256(uint224(params));

        if (msgValue_ < expectedMsgValue) revert InsufficientMsgValue();
    }

    function setExecutionFees(
        uint256 nonce_,
        uint32 dstChainSlug_,
        uint256 executionFees_,
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
                    executionFees_
                )
            ),
            signature_
        );

        _checkRoleWithSlug(FEES_UPDATER_ROLE, dstChainSlug_, feesUpdater);

        uint256 nonce = nextNonce[feesUpdater]++;
        if (nonce_ != nonce) revert InvalidNonce();

        executionFees[dstChainSlug_] = executionFees_;
        emit ExecutionFeesSet(dstChainSlug_, executionFees_);
    }

    function setRelativeNativeTokenPrice(
        uint256 nonce_,
        uint32 dstChainSlug_,
        uint256 relativeNativeTokenPrice_,
        bytes calldata signature_
    ) external override {
        address feesUpdater = signatureVerifier__.recoverSignerFromDigest(
            keccak256(
                abi.encode(
                    RELATIVE_NATIVE_TOKEN_PRICE_UPDATE_SIG_IDENTIFIER,
                    address(this),
                    chainSlug,
                    dstChainSlug_,
                    nonce_,
                    relativeNativeTokenPrice_
                )
            ),
            signature_
        );

        _checkRoleWithSlug(FEES_UPDATER_ROLE, dstChainSlug_, feesUpdater);

        uint256 nonce = nextNonce[feesUpdater]++;
        if (nonce_ != nonce) revert InvalidNonce();

        relativeNativeTokenPrice[dstChainSlug_] = relativeNativeTokenPrice_;
        emit RelativeNativeTokenPriceSet(
            dstChainSlug_,
            relativeNativeTokenPrice_
        );
    }

    function setMsgValueMinThreshold(
        uint256 nonce_,
        uint32 dstChainSlug_,
        uint256 msgValueMinThreshold_,
        bytes calldata signature_
    ) external override {
        address feesUpdater = signatureVerifier__.recoverSignerFromDigest(
            keccak256(
                abi.encode(
                    MSG_VALUE_MIN_THRESHOLD_SIG_IDENTIFIER,
                    address(this),
                    chainSlug,
                    dstChainSlug_,
                    nonce_,
                    msgValueMinThreshold_
                )
            ),
            signature_
        );

        _checkRoleWithSlug(FEES_UPDATER_ROLE, dstChainSlug_, feesUpdater);

        uint256 nonce = nextNonce[feesUpdater]++;
        if (nonce_ != nonce) revert InvalidNonce();

        msgValueMinThreshold[dstChainSlug_] = msgValueMinThreshold_;
        emit MsgValueMinThresholdSet(dstChainSlug_, msgValueMinThreshold_);
    }

    function setMsgValueMaxThreshold(
        uint256 nonce_,
        uint32 dstChainSlug_,
        uint256 msgValueMaxThreshold_,
        bytes calldata signature_
    ) external override {
        address feesUpdater = signatureVerifier__.recoverSignerFromDigest(
            keccak256(
                abi.encode(
                    MSG_VALUE_MAX_THRESHOLD_SIG_IDENTIFIER,
                    address(this),
                    chainSlug,
                    dstChainSlug_,
                    nonce_,
                    msgValueMaxThreshold_
                )
            ),
            signature_
        );

        _checkRoleWithSlug(FEES_UPDATER_ROLE, dstChainSlug_, feesUpdater);

        uint256 nonce = nextNonce[feesUpdater]++;
        if (nonce_ != nonce) revert InvalidNonce();

        msgValueMaxThreshold[dstChainSlug_] = msgValueMaxThreshold_;
        emit MsgValueMaxThresholdSet(dstChainSlug_, msgValueMaxThreshold_);
    }

    /**
     * @notice withdraws fees from contract
     * @param account_ withdraw fees to
     */
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

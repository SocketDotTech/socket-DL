// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;
import "./interfaces/IExecutionManager.sol";
import "./interfaces/ISocket.sol";
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
    ISocket public immutable socket__;
    uint32 public immutable chainSlug;

    /**
     * @notice Emitted when the executionFees is updated
     * @param dstChainSlug The destination chain slug for which the executionFees is updated
     * @param executionFees The new executionFees
     */
    event ExecutionFeesSet(uint256 dstChainSlug, uint128 executionFees);

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

    struct TotalTransmissionAndExecutionFees {
        uint128 totalTransmissionFees;
        uint128 totalExecutionFees;
    }

    mapping(uint32 => TotalTransmissionAndExecutionFees)
        public totalTransmissionExecutionFees;

    mapping(address => mapping(uint32 => uint128)) public totalSwitchboardFees;

    // transmitter => nextNonce
    mapping(address => uint256) public nextNonce;

    // remoteChainSlug => executionFees
    mapping(uint32 => uint128) public executionFees;

    mapping(address => mapping(uint32 => uint128)) transmissionMinFees;

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
    error InsufficientFees();
    error InvalidTransmitManager();

    /**
     * @dev Constructor for ExecutionManager contract
     * @param owner_ Address of the contract owner
     */
    constructor(
        address owner_,
        uint32 chainSlug_,
        ISignatureVerifier signatureVerifier_,
        ISocket socket_
    ) AccessControlExtended(owner_) {
        chainSlug = chainSlug_;
        signatureVerifier__ = signatureVerifier_;
        socket__ = ISocket(socket_);
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
        executor = signatureVerifier__.recoverSigner(packedMessage, sig);
        isValidExecutor = _hasRole(EXECUTOR_ROLE, executor);
    }

    /**
     * @dev Function to be used for on-chain fee distribution later
     */
    function updateExecutionFees(address, uint128, bytes32) external override {}

    function updateTransmissionMinFees(
        uint32 remoteChainSlug_,
        uint128 fees_
    ) external override {
        transmissionMinFees[msg.sender][remoteChainSlug_] = fees_;
    }

    function payAndCheckFees(
        uint256 msgGasLimit_,
        uint256 payloadSize_,
        bytes32 executionParams_,
        uint32 siblingChainSlug_,
        uint128 switchboardFees_,
        uint128 verificationFees_,
        address transmitManager_,
        address switchboard_,
        uint256 maxPacketLength_
    )
        external
        payable
        override
        returns (uint128 executionFee, uint128 transmissionFees)
    {
        transmissionFees =
            transmissionMinFees[transmitManager_][siblingChainSlug_] /
            uint128(maxPacketLength_);

        uint128 minMsgExecutionFees = uint128(
            _getMinFees(
                msgGasLimit_,
                payloadSize_,
                executionParams_,
                siblingChainSlug_
            )
        );
        uint128 minExecutionFees = minMsgExecutionFees + verificationFees_;
        if (msg.value < transmissionFees + switchboardFees_ + minExecutionFees)
            revert InsufficientFees();

        executionFee;

        // any extra fee is considered as executionFee
        // Have to recheck overflow/underflow conditions here
        executionFee = uint128(
            msg.value - uint256(transmissionFees) - uint256(switchboardFees_)
        );

        TotalTransmissionAndExecutionFees
            memory currentTotalFees = totalTransmissionExecutionFees[
                siblingChainSlug_
            ];
        totalTransmissionExecutionFees[
            siblingChainSlug_
        ] = TotalTransmissionAndExecutionFees({
            totalTransmissionFees: currentTotalFees.totalTransmissionFees +
                transmissionFees,
            totalExecutionFees: currentTotalFees.totalExecutionFees +
                executionFee
        });
        totalSwitchboardFees[switchboard_][
            siblingChainSlug_
        ] += switchboardFees_;
    }

    /**
     * @notice Function for getting the minimum fees required for executing a cross-chain transaction
     * @dev This function is called at source to calculate the execution cost.
     * @param siblingChainSlug_ Sibling chain identifier
     * @param payloadSize_ byte length of payload. Currently only used to check max length, later on will be used for fees calculation.
     * @param executionParams_ Can be used for providing extra information. Currently used for msgValue
     * @return minExecutionFee : Minimum fees required for executing the transaction
     */
    function getMinFees(
        uint256 gasLimit_,
        uint256 payloadSize_,
        bytes32 executionParams_,
        uint32 siblingChainSlug_
    ) external view override returns (uint128 minExecutionFee) {
        minExecutionFee = uint128(
            _getMinFees(
                gasLimit_,
                payloadSize_,
                executionParams_,
                siblingChainSlug_
            )
        );
    }

    function getExecutionTransmissionMinFees(
        uint256 msgGasLimit_,
        uint256 payloadSize_,
        bytes32 executionParams_,
        uint32 siblingChainSlug_,
        address transmitManager_
    )
        external
        view
        override
        returns (uint128 minExecutionFee, uint128 transmissionFees)
    {
        minExecutionFee = uint128(
            _getMinFees(
                msgGasLimit_,
                payloadSize_,
                executionParams_,
                siblingChainSlug_
            )
        );
        transmissionFees = transmissionMinFees[transmitManager_][
            siblingChainSlug_
        ];
    }

    function _getMinFees(
        uint256 gasLimit_,
        uint256 payloadSize_,
        bytes32 executionParams_,
        uint32 siblingChainSlug_
    ) internal view returns (uint256) {
        if (payloadSize_ > 3000) revert PayloadTooLarge();

        uint256 params = uint256(executionParams_);
        uint8 paramType = uint8(params >> 248);

        if (paramType == 0) return executionFees[siblingChainSlug_];

        uint256 msgValue = uint256(uint248(params));

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
        bytes32 executionParams_,
        uint256 msgValue_
    ) external pure override {
        uint256 params = uint256(executionParams_);
        uint8 paramType = uint8(params >> 248);

        if (paramType == 0) return;

        uint256 expectedMsgValue = uint256(uint248(params));

        if (msgValue_ < expectedMsgValue) revert InsufficientMsgValue();
    }

    function setExecutionFees(
        uint256 nonce_,
        uint32 dstChainSlug_,
        uint128 executionFees_,
        bytes calldata signature_
    ) external override {
        address feesUpdater = signatureVerifier__.recoverSigner(
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
        if (nonce_ != nextNonce[feesUpdater]++) revert InvalidNonce();

        executionFees[dstChainSlug_] = executionFees_;
        emit ExecutionFeesSet(dstChainSlug_, executionFees_);
    }

    function setRelativeNativeTokenPrice(
        uint256 nonce_,
        uint32 dstChainSlug_,
        uint256 relativeNativeTokenPrice_,
        bytes calldata signature_
    ) external override {
        address feesUpdater = signatureVerifier__.recoverSigner(
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

        if (nonce_ != nextNonce[feesUpdater]++) revert InvalidNonce();

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
        address feesUpdater = signatureVerifier__.recoverSigner(
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
        if (nonce_ != nextNonce[feesUpdater]++) revert InvalidNonce();

        msgValueMinThreshold[dstChainSlug_] = msgValueMinThreshold_;
        emit MsgValueMinThresholdSet(dstChainSlug_, msgValueMinThreshold_);
    }

    function setMsgValueMaxThreshold(
        uint256 nonce_,
        uint32 dstChainSlug_,
        uint256 msgValueMaxThreshold_,
        bytes calldata signature_
    ) external override {
        address feesUpdater = signatureVerifier__.recoverSigner(
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

        if (nonce_ != nextNonce[feesUpdater]++) revert InvalidNonce();

        msgValueMaxThreshold[dstChainSlug_] = msgValueMaxThreshold_;
        emit MsgValueMaxThresholdSet(dstChainSlug_, msgValueMaxThreshold_);
    }

    /**
     * @notice withdraws fees from contract
     * @param siblingChainSlug_ withdraw fees corresponding to this slug
     * @param amount_ withdraw amount
     * @param account_ withdraw fees to
     */
    function withdrawExecutionFees(
        uint32 siblingChainSlug_,
        uint128 amount_,
        address account_
    ) external onlyRole(WITHDRAW_ROLE) {
        if (
            totalTransmissionExecutionFees[siblingChainSlug_]
                .totalExecutionFees < amount_
        ) revert InsufficientFees();

        totalTransmissionExecutionFees[siblingChainSlug_]
            .totalExecutionFees -= amount_;
        (bool success, ) = account_.call{value: amount_}("");
        require(success, "withdraw execution fee failed");
    }

    /**
     * @notice withdraws switchboard fees from contract
     * @param siblingChainSlug_ withdraw fees corresponding to this slug
     * @param amount_ withdraw amount
     */
    function withdrawSwitchboardFees(
        uint32 siblingChainSlug_,
        uint128 amount_
    ) external override {
        if (totalSwitchboardFees[msg.sender][siblingChainSlug_] < amount_)
            revert InsufficientFees();

        totalSwitchboardFees[msg.sender][siblingChainSlug_] -= amount_;
        (bool success, ) = msg.sender.call{value: amount_}("");
        require(success, "withdraw switchboard fee failed");
    }

    /**
     * @notice withdraws transmission fees from contract
     * @param siblingChainSlug_ withdraw fees corresponding to this slug
     * @param amount_ withdraw amount
     */
    function withdrawTransmissionFees(
        uint32 siblingChainSlug_,
        uint128 amount_
    ) external override {
        if (msg.sender != socket__.transmitManager())
            revert InvalidTransmitManager();

        if (
            totalTransmissionExecutionFees[siblingChainSlug_]
                .totalTransmissionFees < amount_
        ) revert InsufficientFees();
        totalTransmissionExecutionFees[siblingChainSlug_]
            .totalTransmissionFees -= amount_;
        (bool success, ) = msg.sender.call{value: amount_}("");
        require(success, "withdraw transmit fee failed");
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

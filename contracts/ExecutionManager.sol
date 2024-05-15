// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "./interfaces/ISwitchboard.sol";
import "./interfaces/ISocket.sol";
import "./interfaces/ISignatureVerifier.sol";
import "./libraries/RescueFundsLib.sol";
import "./utils/AccessControlExtended.sol";
import {WITHDRAW_ROLE, RESCUE_ROLE, EXECUTOR_ROLE, FEES_UPDATER_ROLE, SOCKET_RELAYER_ROLE} from "./utils/AccessRoles.sol";
import {FEES_UPDATE_SIG_IDENTIFIER, RELATIVE_NATIVE_TOKEN_PRICE_UPDATE_SIG_IDENTIFIER, MSG_VALUE_MAX_THRESHOLD_SIG_IDENTIFIER, MSG_VALUE_MIN_THRESHOLD_SIG_IDENTIFIER} from "./utils/SigIdentifiers.sol";

/**
 * @title ExecutionManager
 * @dev Implementation of the IExecutionManager interface, providing functions for executing cross-chain transactions and
 * managing execution and other fees. This contract also implements the AccessControl interface, allowing for role-based
 * access control.
 */
contract ExecutionManager is IExecutionManager, AccessControlExtended {
    ISignatureVerifier public immutable signatureVerifier__;
    ISocket public immutable socket__;
    uint32 public immutable chainSlug;

    /**
     * @notice Emitted when the executionFees is updated
     * @param siblingChainSlug The destination chain slug for which the executionFees is updated
     * @param executionFees The new executionFees
     */
    event ExecutionFeesSet(uint256 siblingChainSlug, uint128 executionFees);

    /**
     * @notice Emitted when the relativeNativeTokenPrice is updated
     * @param siblingChainSlug The destination chain slug for which the relativeNativeTokenPrice is updated
     * @param relativeNativeTokenPrice The new relativeNativeTokenPrice
     */
    event RelativeNativeTokenPriceSet(
        uint256 siblingChainSlug,
        uint256 relativeNativeTokenPrice
    );

    /**
     * @notice Emitted when the msgValueMaxThresholdSet is updated
     * @param siblingChainSlug The destination chain slug for which the msgValueMaxThresholdSet is updated
     * @param msgValueMaxThresholdSet The new msgValueMaxThresholdSet
     */
    event MsgValueMaxThresholdSet(
        uint256 siblingChainSlug,
        uint256 msgValueMaxThresholdSet
    );

    /**
     * @notice Emitted when the msgValueMinThresholdSet is updated
     * @param siblingChainSlug The destination chain slug for which the msgValueMinThresholdSet is updated
     * @param msgValueMinThresholdSet The new msgValueMinThresholdSet
     */
    event MsgValueMinThresholdSet(
        uint256 siblingChainSlug,
        uint256 msgValueMinThresholdSet
    );

    /**
     * @notice Emitted when the execution fees is withdrawn
     * @param account The address to which fees is transferred
     * @param siblingChainSlug The destination chain slug for which the fees is withdrawn
     * @param amount The amount withdrawn
     */
    event ExecutionFeesWithdrawn(
        address account,
        uint32 siblingChainSlug,
        uint256 amount
    );

    /**
     * @notice Emitted when the transmission fees is withdrawn
     * @param transmitManager The address of transmit manager to which fees is transferred
     * @param siblingChainSlug The destination chain slug for which the fees is withdrawn
     * @param amount The amount withdrawn
     */
    event TransmissionFeesWithdrawn(
        address transmitManager,
        uint32 siblingChainSlug,
        uint256 amount
    );

    /**
     * @notice Emitted when the switchboard fees is withdrawn
     * @param switchboard The address of switchboard for which fees is claimed
     * @param siblingChainSlug The destination chain slug for which the fees is withdrawn
     * @param amount The amount withdrawn
     */
    event SwitchboardFeesWithdrawn(
        address switchboard,
        uint32 siblingChainSlug,
        uint256 amount
    );

    /**
     * @notice packs the total execution and transmission fees received for a sibling slug
     */
    struct TotalExecutionAndTransmissionFees {
        uint128 totalExecutionFees;
        uint128 totalTransmissionFees;
    }

    // maps total fee collected with chain slug
    mapping(uint32 => TotalExecutionAndTransmissionFees)
        public totalExecutionAndTransmissionFees;

    // switchboard => chain slug => switchboard fees collected
    mapping(address => mapping(uint32 => uint128)) public totalSwitchboardFees;

    // transmitter => nextNonce
    mapping(address => uint256) public nextNonce;

    // remoteChainSlug => executionFees
    mapping(uint32 => uint128) public executionFees;

    // transmit manager => chain slug => switchboard fees collected
    mapping(address => mapping(uint32 => uint128)) public transmissionMinFees;

    // relativeNativeTokenPrice is used to convert fees to destination terms when sending value along with message
    // destSlug => relativeNativePrice (stores (destnativeTokenPriceUSD*(1e18)/srcNativeTokenPriceUSD))
    mapping(uint32 => uint256) public relativeNativeTokenPrice;

    // supported min amount of native value to send with message
    // chain slug => min msg value threshold
    mapping(uint32 => uint256) public msgValueMinThreshold;

    // supported max amount of native value to send with message
    // chain slug => max msg value threshold
    mapping(uint32 => uint256) public msgValueMaxThreshold;

    // triggered when nonce in signature is invalid
    error InvalidNonce();

    // triggered when msg value less than min threshold
    error MsgValueTooLow();

    // triggered when msg value more than max threshold
    error MsgValueTooHigh();

    // triggered when payload is larger than expected limit
    error PayloadTooLarge();

    // triggered when msg value is not enough
    error InsufficientMsgValue();

    // triggered when fees is not enough
    error InsufficientFees();

    // triggered when msg value exceeds uint128 max value
    error InvalidMsgValue();

    // triggered when fees exceeds uint128 max value
    error FeesTooHigh();

    error OnlySocket();

    /**
     * @dev Constructor for ExecutionManager contract
     * @param owner_ address of the contract owner
     * @param chainSlug_ chain slug, unique identifier of chain deployed on
     * @param signatureVerifier_ the signature verifier contract
     * @param socket_ the socket contract
     */
    constructor(
        address owner_,
        uint32 chainSlug_,
        ISocket socket_,
        ISignatureVerifier signatureVerifier_
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
     * @notice updates the total fee used by an executor to execute a message
     * @dev to be used for accounting when onchain fee distribution for individual executors is implemented
     * @dev this function should be called by socket only
     * @inheritdoc IExecutionManager
     */
    function updateExecutionFees(
        address,
        uint128,
        bytes32
    ) external view override {
        if (msg.sender != address(socket__)) revert OnlySocket();
    }

    /// @inheritdoc IExecutionManager
    function payAndCheckFees(
        uint256 minMsgGasLimit_,
        uint256 payloadSize_,
        bytes32 executionParams_,
        bytes32,
        uint32 siblingChainSlug_,
        uint128 switchboardFees_,
        uint128 verificationOverheadFees_,
        address transmitManager_,
        address switchboard_,
        uint256 maxPacketLength_
    )
        external
        payable
        override
        onlyRole(SOCKET_RELAYER_ROLE)
        returns (uint128 executionFee, uint128 transmissionFees)
    {
        if (msg.value >= type(uint128).max) revert InvalidMsgValue();
        uint128 msgValue = uint128(msg.value);

        // transmission fees are per packet, so need to divide by number of messages per packet
        transmissionFees =
            transmissionMinFees[transmitManager_][siblingChainSlug_] /
            uint128(maxPacketLength_);

        uint128 minMsgExecutionFees = _getMinFees(
            minMsgGasLimit_,
            payloadSize_,
            executionParams_,
            siblingChainSlug_
        );

        uint128 minExecutionFees = minMsgExecutionFees +
            verificationOverheadFees_;
        if (msgValue < transmissionFees + switchboardFees_ + minExecutionFees)
            revert InsufficientFees();

        // any extra fee is considered as executionFee
        executionFee = msgValue - transmissionFees - switchboardFees_;

        TotalExecutionAndTransmissionFees
            memory currentTotalFees = totalExecutionAndTransmissionFees[
                siblingChainSlug_
            ];

        totalExecutionAndTransmissionFees[
            siblingChainSlug_
        ] = TotalExecutionAndTransmissionFees({
            totalExecutionFees: currentTotalFees.totalExecutionFees +
                executionFee,
            totalTransmissionFees: currentTotalFees.totalTransmissionFees +
                transmissionFees
        });

        totalSwitchboardFees[switchboard_][
            siblingChainSlug_
        ] += switchboardFees_;
    }

    /**
     * @notice function for getting the minimum fees required for executing msg on destination
     * @dev this function is called at source to calculate the execution cost.
     * @param gasLimit_ the gas limit needed for execution at destination
     * @param payloadSize_ byte length of payload. Currently only used to check max length, later on will be used for fees calculation.
     * @param executionParams_ Can be used for providing extra information. Currently used for msgValue
     * @param siblingChainSlug_ Sibling chain identifier
     * @return minExecutionFee : Minimum fees required for executing the transaction
     */
    function getMinFees(
        uint256 gasLimit_,
        uint256 payloadSize_,
        bytes32 executionParams_,
        uint32 siblingChainSlug_
    ) external view override returns (uint128 minExecutionFee) {
        minExecutionFee = _getMinFees(
            gasLimit_,
            payloadSize_,
            executionParams_,
            siblingChainSlug_
        );
    }

    /// @inheritdoc IExecutionManager
    function getExecutionTransmissionMinFees(
        uint256 minMsgGasLimit_,
        uint256 payloadSize_,
        bytes32 executionParams_,
        bytes32,
        uint32 siblingChainSlug_,
        address transmitManager_
    )
        external
        view
        override
        returns (uint128 minExecutionFee, uint128 transmissionFees)
    {
        minExecutionFee = _getMinFees(
            minMsgGasLimit_,
            payloadSize_,
            executionParams_,
            siblingChainSlug_
        );
        transmissionFees = transmissionMinFees[transmitManager_][
            siblingChainSlug_
        ];
    }

    // decodes and validates the msg value if it is under given transfer limits and calculates
    // the total fees needed for execution for given payload size and msg value.
    function _getMinFees(
        uint256,
        uint256 payloadSize_,
        bytes32 executionParams_,
        uint32 siblingChainSlug_
    ) internal view returns (uint128) {
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

        uint256 totalNativeValue = msgValueRequiredOnSrcChain +
            executionFees[siblingChainSlug_];

        if (totalNativeValue >= type(uint128).max) revert FeesTooHigh();
        return uint128(totalNativeValue);
    }

    /**
     * @notice called by socket while executing message to validate if the msg value provided is enough
     * @param executionParams_ a bytes32 string where first byte gives param type (if value is 0 or not)
     * and remaining bytes give the msg value needed
     * @param msgValue_ msg.value to be sent with inbound
     */
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

    /**
     * @notice sets the minimum execution fees required for executing at `siblingChainSlug_`
     * @dev this function currently sets the price for a constant msg gas limit and payload size but this will be
     * updated in future to consider gas limit and payload size to return fees which will be close to
     * actual execution cost.
     * @param nonce_ incremental id to prevent signature replay
     * @param siblingChainSlug_ sibling chain identifier
     * @param executionFees_ total fees where price in destination native token is converted to source native tokens
     * @param signature_ signature of fee updater
     */
    function setExecutionFees(
        uint256 nonce_,
        uint32 siblingChainSlug_,
        uint128 executionFees_,
        bytes calldata signature_
    ) external override {
        address feesUpdater = signatureVerifier__.recoverSigner(
            keccak256(
                abi.encode(
                    FEES_UPDATE_SIG_IDENTIFIER,
                    address(this),
                    chainSlug,
                    siblingChainSlug_,
                    nonce_,
                    executionFees_
                )
            ),
            signature_
        );

        _checkRoleWithSlug(FEES_UPDATER_ROLE, siblingChainSlug_, feesUpdater);

        // nonce is used by gated roles and we don't expect nonce to reach the max value of uint256
        unchecked {
            if (nonce_ != nextNonce[feesUpdater]++) revert InvalidNonce();
        }

        executionFees[siblingChainSlug_] = executionFees_;
        emit ExecutionFeesSet(siblingChainSlug_, executionFees_);
    }

    /**
     * @notice sets the relative token price for `siblingChainSlug_`
     * @dev this function is expected to be called frequently to match the original prices
     * @param nonce_ incremental id to prevent signature replay
     * @param siblingChainSlug_ sibling chain identifier
     * @param relativeNativeTokenPrice_ relative price
     * @param signature_ signature of fee updater
     */
    function setRelativeNativeTokenPrice(
        uint256 nonce_,
        uint32 siblingChainSlug_,
        uint256 relativeNativeTokenPrice_,
        bytes calldata signature_
    ) external override {
        address feesUpdater = signatureVerifier__.recoverSigner(
            keccak256(
                abi.encode(
                    RELATIVE_NATIVE_TOKEN_PRICE_UPDATE_SIG_IDENTIFIER,
                    address(this),
                    chainSlug,
                    siblingChainSlug_,
                    nonce_,
                    relativeNativeTokenPrice_
                )
            ),
            signature_
        );

        _checkRoleWithSlug(FEES_UPDATER_ROLE, siblingChainSlug_, feesUpdater);

        // nonce is used by gated roles and we don't expect nonce to reach the max value of uint256
        unchecked {
            if (nonce_ != nextNonce[feesUpdater]++) revert InvalidNonce();
        }

        relativeNativeTokenPrice[siblingChainSlug_] = relativeNativeTokenPrice_;
        emit RelativeNativeTokenPriceSet(
            siblingChainSlug_,
            relativeNativeTokenPrice_
        );
    }

    /**
     * @notice sets the min limit for msg value for `siblingChainSlug_`
     * @param nonce_ incremental id to prevent signature replay
     * @param siblingChainSlug_ sibling chain identifier
     * @param msgValueMinThreshold_ min msg value
     * @param signature_ signature of fee updater
     */
    function setMsgValueMinThreshold(
        uint256 nonce_,
        uint32 siblingChainSlug_,
        uint256 msgValueMinThreshold_,
        bytes calldata signature_
    ) external override {
        address feesUpdater = signatureVerifier__.recoverSigner(
            keccak256(
                abi.encode(
                    MSG_VALUE_MIN_THRESHOLD_SIG_IDENTIFIER,
                    address(this),
                    chainSlug,
                    siblingChainSlug_,
                    nonce_,
                    msgValueMinThreshold_
                )
            ),
            signature_
        );

        _checkRoleWithSlug(FEES_UPDATER_ROLE, siblingChainSlug_, feesUpdater);

        // nonce is used by gated roles and we don't expect nonce to reach the max value of uint256
        unchecked {
            if (nonce_ != nextNonce[feesUpdater]++) revert InvalidNonce();
        }
        msgValueMinThreshold[siblingChainSlug_] = msgValueMinThreshold_;
        emit MsgValueMinThresholdSet(siblingChainSlug_, msgValueMinThreshold_);
    }

    /**
     * @notice sets the max limit for msg value for `siblingChainSlug_`
     * @param nonce_ incremental id to prevent signature replay
     * @param siblingChainSlug_ sibling chain identifier
     * @param msgValueMaxThreshold_ max msg value
     * @param signature_ signature of fee updater
     */
    function setMsgValueMaxThreshold(
        uint256 nonce_,
        uint32 siblingChainSlug_,
        uint256 msgValueMaxThreshold_,
        bytes calldata signature_
    ) external override {
        address feesUpdater = signatureVerifier__.recoverSigner(
            keccak256(
                abi.encode(
                    MSG_VALUE_MAX_THRESHOLD_SIG_IDENTIFIER,
                    address(this),
                    chainSlug,
                    siblingChainSlug_,
                    nonce_,
                    msgValueMaxThreshold_
                )
            ),
            signature_
        );

        _checkRoleWithSlug(FEES_UPDATER_ROLE, siblingChainSlug_, feesUpdater);

        // nonce is used by gated roles and we don't expect nonce to reach the max value of uint256
        unchecked {
            if (nonce_ != nextNonce[feesUpdater]++) revert InvalidNonce();
        }
        msgValueMaxThreshold[siblingChainSlug_] = msgValueMaxThreshold_;
        emit MsgValueMaxThresholdSet(siblingChainSlug_, msgValueMaxThreshold_);
    }

    /**
     * @notice updates the transmission fee needed for transmission
     * @dev this function stores value against msg.sender hence expected to be called by transmit manager
     * @inheritdoc IExecutionManager
     */
    function setTransmissionMinFees(
        uint32 remoteChainSlug_,
        uint128 fees_
    ) external override {
        transmissionMinFees[msg.sender][remoteChainSlug_] = fees_;
    }

    /**
     * @notice withdraws fees for execution from contract
     * @param siblingChainSlug_ withdraw fees corresponding to this slug
     * @param amount_ withdraw amount
     * @param withdrawTo_ withdraw fees to the provided address
     */
    function withdrawExecutionFees(
        uint32 siblingChainSlug_,
        uint128 amount_,
        address withdrawTo_
    ) external onlyRole(WITHDRAW_ROLE) {
        if (withdrawTo_ == address(0)) revert ZeroAddress();
        if (
            totalExecutionAndTransmissionFees[siblingChainSlug_]
                .totalExecutionFees < amount_
        ) revert InsufficientFees();

        totalExecutionAndTransmissionFees[siblingChainSlug_]
            .totalExecutionFees -= amount_;

        SafeTransferLib.safeTransferETH(withdrawTo_, amount_);
        emit ExecutionFeesWithdrawn(withdrawTo_, siblingChainSlug_, amount_);
    }

    /**
     * @notice withdraws switchboard fees from contract
     * @param siblingChainSlug_ withdraw fees corresponding to this slug
     * @param amount_ withdraw amount
     */
    function withdrawSwitchboardFees(
        uint32 siblingChainSlug_,
        address switchboard_,
        uint128 amount_
    ) external override onlyRole(SOCKET_RELAYER_ROLE) {
        if (totalSwitchboardFees[switchboard_][siblingChainSlug_] < amount_)
            revert InsufficientFees();

        totalSwitchboardFees[switchboard_][siblingChainSlug_] -= amount_;
        ISwitchboard(switchboard_).receiveFees{value: amount_}(
            siblingChainSlug_
        );

        emit SwitchboardFeesWithdrawn(switchboard_, siblingChainSlug_, amount_);
    }

    /**
     * @dev this function gets the transmitManager address from the socket contract. If it is ever upgraded in socket,
     * @dev remove the fees from executionManager first, and then upgrade address at socket.
     * @notice withdraws transmission fees from contract
     * @param siblingChainSlug_ withdraw fees corresponding to this slug
     * @param amount_ withdraw amount
     */
    function withdrawTransmissionFees(
        uint32 siblingChainSlug_,
        uint128 amount_
    ) external override onlyRole(SOCKET_RELAYER_ROLE) {
        if (
            totalExecutionAndTransmissionFees[siblingChainSlug_]
                .totalTransmissionFees < amount_
        ) revert InsufficientFees();

        totalExecutionAndTransmissionFees[siblingChainSlug_]
            .totalTransmissionFees -= amount_;

        ITransmitManager tm = socket__.transmitManager__();
        tm.receiveFees{value: amount_}(siblingChainSlug_);
        emit TransmissionFeesWithdrawn(address(tm), siblingChainSlug_, amount_);
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
}

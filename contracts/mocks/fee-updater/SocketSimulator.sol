pragma solidity 0.8.19;

import "../../capacitors/SingleCapacitor.sol";
import "../../decapacitors/SingleDecapacitor.sol";
import "../../utils/AccessControl.sol";
import "../../interfaces/IHasher.sol";
import "../../interfaces/ISignatureVerifier.sol";

import "../../interfaces/IPlug.sol";
import "../../interfaces/ISwitchboard.sol";

interface ISimulatorUtils {
    function checkTransmitter(
        uint32 siblingSlug_,
        bytes32 digest_,
        bytes calldata signature_
    ) external view returns (address, bool);

    function updateExecutionFees(address, uint128, bytes32) external view;

    function verifyParams(
        bytes32 executionParams_,
        uint256 msgValue_
    ) external pure;

    function isExecutor(
        bytes32 packedMessage,
        bytes memory sig
    ) external view returns (address executor, bool isValidExecutor);
}

contract SocketSimulator is AccessControl {
    ISimulatorUtils public utils__;
    ISignatureVerifier public signatureVerifier__;
    IHasher public hasher__;
    SingleCapacitor public capacitor;

    bytes32 public immutable version;
    uint32 public immutable chainSlug;
    uint32 public immutable siblingChain;
    mapping(address => uint32) public capacitorToSlug;

    mapping(bytes32 => uint256) public proposalCount;
    mapping(bytes32 => mapping(uint256 => mapping(address => bytes32)))
        public packetIdRoots;
    mapping(bytes32 => mapping(uint256 => mapping(address => uint256)))
        public rootProposedAt;
    mapping(bytes32 => bool) public messageExecuted;

    struct PlugConfig {
        // address of the sibling plug on the remote chain
        address siblingPlug;
        // capacitor instance for the outbound plug connection
        ICapacitor capacitor__;
        // decapacitor instance for the inbound plug connection
        IDecapacitor decapacitor__;
        // inbound switchboard instance for the plug connection
        ISwitchboard inboundSwitchboard__;
        // outbound switchboard instance for the plug connection
        ISwitchboard outboundSwitchboard__;
    }

    // plug => remoteChainSlug => (siblingPlug, capacitor__, decapacitor__, inboundSwitchboard__, outboundSwitchboard__)
    mapping(address => mapping(uint32 => PlugConfig)) internal _plugConfigs;

    error InvalidCapacitorAddress();
    error InvalidPacketId();
    error MessageAlreadyExecuted();
    error LowGasLimit();
    error ErrInSourceValidation();
    error PacketNotProposed();
    error NotExecutor();
    error VerificationFailed();
    error InvalidProof();

    event Sealed(
        address indexed transmitter,
        bytes32 indexed packetId,
        uint256 batchSize,
        bytes32 root,
        bytes signature
    );
    event PacketProposed(
        address indexed transmitter,
        bytes32 indexed packetId,
        uint256 proposalCount,
        bytes32 root,
        address switchboard
    );
    event ExecutionSuccess(bytes32 msgId);

    constructor(
        uint32 chainSlug_,
        uint32 siblingChainSlug_,
        address hasher_,
        address signatureVerifier_,
        string memory version_
    ) AccessControl(msg.sender) {
        chainSlug = chainSlug_;
        siblingChain = siblingChainSlug_;
        version = keccak256(bytes(version_));
        hasher__ = IHasher(hasher_);
        signatureVerifier__ = ISignatureVerifier(signatureVerifier_);
    }

    function setup(
        address plug_,
        address switchboard_,
        address utils_
    ) external onlyOwner {
        utils__ = ISimulatorUtils(utils_);

        bytes32 packedMessage = hasher__.packMessage(
            chainSlug,
            plug_,
            siblingChain,
            plug_,
            ISocket.MessageDetails(
                bytes32(
                    (uint256(chainSlug) << 224) |
                        (uint256(uint160(plug_)) << 64) |
                        0
                ),
                0,
                12000,
                bytes32(0),
                bytes("")
            )
        );

        capacitor = new SingleCapacitor(address(this), msg.sender);
        PlugConfig storage plugConfig = _plugConfigs[plug_][siblingChain];

        capacitorToSlug[address(capacitor)] = siblingChain;
        plugConfig.siblingPlug = plug_;
        plugConfig.capacitor__ = capacitor;
        plugConfig.decapacitor__ = new SingleDecapacitor(msg.sender);
        plugConfig.inboundSwitchboard__ = ISwitchboard(switchboard_);
        plugConfig.outboundSwitchboard__ = ISwitchboard(switchboard_);
        plugConfig.capacitor__.addPackedMessage(packedMessage);

        packetIdRoots[_encodePacketId(address(capacitor), 0)][0][
            switchboard_
        ] = bytes32("random");
    }

    /**
     * @notice seals data in capacitor for specific batchSize
     * @param batchSize_ size of batch to be sealed
     * @param capacitorAddress_ address of capacitor
     * @param signature_ signed Data needed for verification
     */
    function seal(
        uint256 batchSize_,
        address capacitorAddress_,
        bytes calldata signature_
    ) external payable onlyOwner {
        uint32 siblingChainSlug = capacitorToSlug[capacitorAddress_];
        if (siblingChain == 0) revert InvalidCapacitorAddress();

        (bytes32 root, uint64 packetCount) = ICapacitor(capacitorAddress_)
            .sealPacket(batchSize_);

        bytes32 packetId = _encodePacketId(capacitorAddress_, packetCount);
        (address transmitter, bool isTransmitter) = utils__.checkTransmitter(
            siblingChain,
            keccak256(abi.encode(version, siblingChain, packetId, root)),
            signature_
        );

        if (siblingChain == 0) revert InvalidCapacitorAddress();
        emit Sealed(transmitter, packetId, batchSize_, root, signature_);
    }

    function proposeForSwitchboard(
        bytes32 packetId_,
        bytes32 root_,
        address switchboard_,
        bytes calldata signature_
    ) external payable onlyOwner {
        if (packetId_ == bytes32(0)) revert InvalidPacketId();

        (address transmitter, bool isTransmitter) = utils__.checkTransmitter(
            _decodeChainSlug(packetId_),
            keccak256(abi.encode(version, chainSlug, packetId_, root_)),
            signature_
        );

        if (packetId_ == bytes32(0)) revert InvalidPacketId();

        packetIdRoots[packetId_][proposalCount[packetId_]][
            switchboard_
        ] = root_;
        rootProposedAt[packetId_][proposalCount[packetId_]][
            switchboard_
        ] = block.timestamp;

        emit PacketProposed(
            transmitter,
            packetId_,
            proposalCount[packetId_]++,
            root_,
            switchboard_
        );
    }

    function execute(
        ISocket.ExecutionDetails calldata executionDetails_,
        ISocket.MessageDetails calldata messageDetails_
    ) external payable onlyOwner {
        // make sure message is not executed already
        if (messageExecuted[messageDetails_.msgId])
            revert MessageAlreadyExecuted();

        // update state to make sure no reentrancy
        messageExecuted[messageDetails_.msgId] = true;

        // make sure caller is calling with right gas limits
        // we also make sure to give executors the ability to execute with higher gas limits
        // than the minimum required
        if (
            executionDetails_.executionGasLimit < messageDetails_.minMsgGasLimit
        ) revert LowGasLimit();

        if (executionDetails_.packetId == bytes32(0)) revert InvalidPacketId();

        // extract chain slug from msgID
        uint32 remoteSlug = _decodeChainSlug(messageDetails_.msgId);

        // make sure packet and msg are for the same chain
        if (_decodeChainSlug(executionDetails_.packetId) != remoteSlug)
            revert ErrInSourceValidation();

        // extract plug address from msgID
        address localPlug = _decodePlug(messageDetails_.msgId);

        // fetch required vars from plug config
        PlugConfig memory plugConfig;
        plugConfig.decapacitor__ = _plugConfigs[localPlug][remoteSlug]
            .decapacitor__;
        plugConfig.siblingPlug = _plugConfigs[localPlug][remoteSlug]
            .siblingPlug;
        plugConfig.inboundSwitchboard__ = _plugConfigs[localPlug][remoteSlug]
            .inboundSwitchboard__;

        // fetch packet root
        bytes32 packetRoot = packetIdRoots[executionDetails_.packetId][
            executionDetails_.proposalCount
        ][address(plugConfig.inboundSwitchboard__)];
        // if (packetRoot == bytes32(0)) revert PacketNotProposed();

        // create packed message
        bytes32 packedMessage = hasher__.packMessage(
            remoteSlug,
            plugConfig.siblingPlug,
            chainSlug,
            localPlug,
            messageDetails_
        );

        // make sure caller is executor
        (address executor, bool isValidExecutor) = utils__.isExecutor(
            packedMessage,
            executionDetails_.signature
        );
        if (!isValidExecutor) revert NotExecutor();

        // finally make sure executor params were respected by the executor
        utils__.verifyParams(messageDetails_.executionParams, msg.value);

        // verify message was part of the packet and
        // authenticated by respective switchboard
        _verify(
            executionDetails_.packetId,
            executionDetails_.proposalCount,
            remoteSlug,
            packedMessage,
            packetRoot,
            plugConfig,
            executionDetails_.decapacitorProof
        );

        // execute message
        _execute(
            executor,
            localPlug,
            remoteSlug,
            executionDetails_.executionGasLimit,
            messageDetails_
        );
    }

    ////////////////////////////////////////////////////////
    ////////////////// INTERNAL FUNCS //////////////////////
    ////////////////////////////////////////////////////////

    function _verify(
        bytes32 packetId_,
        uint256 proposalCount_,
        uint32 remoteChainSlug_,
        bytes32 packedMessage_,
        bytes32 packetRoot_,
        PlugConfig memory plugConfig_,
        bytes memory decapacitorProof_
    ) internal {
        // NOTE: is the the first un-trusted call in the system, another one is Plug.inbound
        if (
            !ISwitchboard(plugConfig_.inboundSwitchboard__).allowPacket(
                packetRoot_,
                packetId_,
                proposalCount_,
                remoteChainSlug_,
                rootProposedAt[packetId_][proposalCount_][
                    address(plugConfig_.inboundSwitchboard__)
                ]
            )
        ) revert VerificationFailed();

        if (
            !plugConfig_.decapacitor__.verifyMessageInclusion(
                packetRoot_,
                packetRoot_,
                decapacitorProof_
            )
        ) revert InvalidProof();
    }

    /**
     * This function assumes localPlug_ will have code while executing. As the message
     * execution failure is not blocking the system, it is not necessary to check if
     * code exists in the given address.
     */
    function _execute(
        address executor_,
        address localPlug_,
        uint32 remoteChainSlug_,
        uint256 executionGasLimit_,
        ISocket.MessageDetails memory messageDetails_
    ) internal {
        // NOTE: external un-trusted call
        IPlug(localPlug_).inbound{gas: executionGasLimit_, value: msg.value}(
            remoteChainSlug_,
            messageDetails_.payload
        );

        utils__.updateExecutionFees(
            executor_,
            uint128(messageDetails_.executionFee),
            messageDetails_.msgId
        );
        emit ExecutionSuccess(messageDetails_.msgId);
    }

    /**
     * @dev Decodes the plug address from a given message id.
     * @param id_ The ID of the msg to decode the plug from.
     * @return plug_ The address of sibling plug decoded from the message ID.
     */
    function _decodePlug(bytes32 id_) internal pure returns (address plug_) {
        plug_ = address(uint160(uint256(id_) >> 64));
    }

    /**
     * @dev Decodes the chain ID from a given packet/message ID.
     * @param id_ The ID of the packet/msg to decode the chain slug from.
     * @return chainSlug_ The chain slug decoded from the packet/message ID.
     */
    function _decodeChainSlug(
        bytes32 id_
    ) internal pure returns (uint32 chainSlug_) {
        chainSlug_ = uint32(uint256(id_) >> 224);
    }

    function _encodePacketId(
        address capacitorAddress_,
        uint64 packetCount_
    ) internal view returns (bytes32) {
        return
            bytes32(
                (uint256(chainSlug) << 224) |
                    (uint256(uint160(capacitorAddress_)) << 64) |
                    packetCount_
            );
    }
}

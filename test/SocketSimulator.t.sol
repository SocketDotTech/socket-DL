// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import "../contracts/utils/SignatureVerifier.sol";
import "../contracts/utils/Hasher.sol";

import "../contracts/utils/AccessRoles.sol";
import "../contracts/utils/SigIdentifiers.sol";
import "../contracts/switchboard/default-switchboards/FastSwitchboard.sol";
import "../contracts/mocks/fee-updater/SocketSimulator.sol";
import "../contracts/mocks/fee-updater/SwitchboardSimulator.sol";
import "../contracts/mocks/fee-updater/SimulatorUtils.sol";

contract Setup is Test {
    uint256 internal c = 1000;
    uint32 internal aChainSlug = uint32(uint256(0x2013AA262));
    uint32 internal bChainSlug = uint32(uint256(0x2013AA263));
    uint32 internal cChainSlug = uint32(uint256(0x2013AA264));

    address public constant NATIVE_TOKEN_ADDRESS =
        address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    string version = "TEST_NET";
    bytes32 versionHash = keccak256(bytes(version));

    address immutable _plugOwner = address(uint160(c++));
    address immutable _raju = address(uint160(c++));
    address immutable _fundRescuer = address(uint160(c++));
    address immutable _feesPayer = address(uint160(c++));
    address immutable _feesWithdrawer = address(uint160(c++));

    address _socketOwner;

    address _executor;
    address _transmitter;
    address _watcher;

    address _altTransmitter;
    address _altWatcher;
    address _altExecutor;

    address _nonTransmitter;
    address _nonWatcher;
    address _nonExecutor;

    uint256 immutable _socketOwnerPrivateKey = c++;
    uint256 immutable _transmitterPrivateKey = c++;
    uint256 immutable _watcherPrivateKey = c++;
    uint256 immutable _executorPrivateKey = c++;

    uint256 immutable _altTransmitterPrivateKey = c++;
    uint256 immutable _altWatcherPrivateKey = c++;
    uint256 immutable _altExecutorPrivateKey = c++;

    uint256 immutable _nonTransmitterPrivateKey = c++;
    uint256 immutable _nonWatcherPrivateKey = c++;
    uint256 immutable _nonExecutorPrivateKey = c++;

    uint256 _socketOwnerNonce;

    uint256 internal _timeoutInSeconds = 0;
    uint256 internal _optimisticTimeoutInSeconds = 1;

    uint256 internal _slowCapacitorWaitTime = 300;
    uint256 internal _minMsgGasLimit = 30548;
    uint256 internal _sealGasLimit = 150000;
    uint128 internal _transmissionFees = 350000000000;
    uint128 internal _switchboardFees = 100000;
    uint128 internal _verificationOverheadFees = 100000;
    uint256 internal _msgValueMaxThreshold = 1000;
    uint256 internal _msgValueMinThreshold = 10;
    uint256 internal _relativeNativeTokenPrice = 1000 * 1e18;

    uint256 internal _executionOverhead = 50000;
    uint256 internal _capacitorType = 1;
    uint256 internal constant DEFAULT_BATCH_LENGTH = 1;

    bytes32 internal _transmissionParams = bytes32(0);
    bool isExecutionOpen = false;

    uint256 maxAllowedPacketLength = 10;

    address internal siblingSwitchboard = address(uint160(c++));

    struct SocketConfigContext {
        uint32 siblingChainSlug;
        uint256 switchboardNonce;
        ICapacitor capacitor__;
        IDecapacitor decapacitor__;
        ISwitchboard switchboard__;
    }

    struct ChainContext {
        uint32 chainSlug;
        uint256 transmitterNonce;
        uint256 executorNonce;
        SocketSimulator socket__;
        Hasher hasher__;
        SignatureVerifier sigVerifier__;
        SimulatorUtils utils__;
        SwitchboardSimulator switchboard__;
    }

    struct ExecutePayloadOnDstParams {
        bytes32 packetId_;
        uint256 proposalCount_;
        bytes32 msgId_;
        uint256 minMsgGasLimit_;
        bytes32 executionParams_;
        uint256 executionFee_;
        bytes32 packedMessage_;
        bytes payload_;
        bytes proof_;
    }

    struct MessageContext {
        uint256 amount;
        uint256 msgId;
        bytes32 root;
        uint256 packetId;
        bytes sig;
        bytes payload;
        bytes proof;
    }

    ChainContext _a;
    ChainContext _b;

    function initialize() internal {
        _socketOwner = vm.addr(_socketOwnerPrivateKey);

        _transmitter = vm.addr(_transmitterPrivateKey);
        _altTransmitter = vm.addr(_altTransmitterPrivateKey);
        _nonTransmitter = vm.addr(_nonTransmitterPrivateKey);

        _executor = vm.addr(_executorPrivateKey);
        _altExecutor = vm.addr(_altExecutorPrivateKey);
        _nonExecutor = vm.addr(_nonExecutorPrivateKey);

        _watcher = vm.addr(_watcherPrivateKey);
        _altWatcher = vm.addr(_altWatcherPrivateKey);
        _nonWatcher = vm.addr(_nonWatcherPrivateKey);
    }

    function _deploySocket(
        ChainContext storage cc_,
        address deployer_,
        bool isExecutionOpen_
    ) internal {
        vm.startPrank(deployer_);

        cc_.hasher__ = new Hasher(deployer_);
        cc_.hasher__.grantRole(RESCUE_ROLE, deployer_);

        cc_.sigVerifier__ = new SignatureVerifier(deployer_);
        cc_.sigVerifier__.grantRole(RESCUE_ROLE, deployer_);

        cc_.socket__ = new SocketSimulator(
            uint32(cc_.chainSlug),
            uint32(cc_.chainSlug),
            address(cc_.hasher__),
            address(cc_.sigVerifier__),
            version
        );

        cc_.utils__ = new SimulatorUtils(
            address(cc_.socket__),
            address(cc_.sigVerifier__),
            deployer_,
            uint32(cc_.chainSlug)
        );

        cc_.switchboard__ = new SwitchboardSimulator(
            deployer_,
            address(cc_.socket__),
            uint32(cc_.chainSlug),
            _timeoutInSeconds,
            cc_.sigVerifier__
        );

        cc_.socket__.setup(address(cc_.switchboard__), address(cc_.utils__));

        vm.stopPrank();
    }

    function _getLatestSignature(
        address capacitor_
    ) internal view returns (bytes32 root, bytes32 packetId, bytes memory sig) {
        uint64 id;
        (root, id) = ICapacitor(capacitor_).getNextPacketToBeSealed();
        packetId = _getPackedId(capacitor_, aChainSlug, id);
        bytes32 digest = keccak256(
            abi.encode(versionHash, aChainSlug, packetId, root)
        );
        sig = _createSignature(digest, _transmitterPrivateKey);
    }

    function _createSignature(
        bytes32 digest_,
        uint256 privateKey_
    ) internal pure returns (bytes memory sig) {
        bytes32 digest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_)
        );
        (uint8 sigV, bytes32 sigR, bytes32 sigS) = vm.sign(privateKey_, digest);
        sig = new bytes(65);
        bytes1 v32 = bytes1(sigV);

        assembly {
            mstore(add(sig, 96), v32)
            mstore(add(sig, 32), sigR)
            mstore(add(sig, 64), sigS)
        }
    }

    function _sealOnSrc(
        ChainContext storage src_,
        address capacitor,
        uint256 batchSize,
        bytes memory sig_
    ) internal {
        src_.socket__.seal(batchSize, capacitor, sig_);

        // random capacitor
        address randomCapacitor = address(uint160(c++));
        vm.expectRevert();
        src_.socket__.seal(batchSize, randomCapacitor, sig_);

        // non-socket capacitor
        SingleCapacitor randomCapacitor__ = new SingleCapacitor(
            address(src_.socket__),
            _socketOwner
        );
        hoax(address(src_.socket__));
        randomCapacitor__.addPackedMessage(bytes32("random"));

        vm.expectRevert(SocketSimulator.InvalidCapacitorAddress.selector);
        src_.socket__.seal(batchSize, address(randomCapacitor__), sig_);
    }

    function _proposeOnDst(
        ChainContext storage dst_,
        bytes memory sig_,
        bytes32 packetId_,
        bytes32 root_,
        address switchboard_
    ) internal {
        dst_.socket__.proposeForSwitchboard(
            packetId_,
            root_,
            switchboard_,
            sig_
        );

        vm.expectRevert(SocketSimulator.InvalidPacketId.selector);
        dst_.socket__.proposeForSwitchboard(
            bytes32(0),
            root_,
            switchboard_,
            sig_
        );
    }

    function _attestOnDst(
        address switchboardAddress,
        uint32 dstSlug,
        bytes32 packetId_,
        uint256 proposalCount_,
        bytes32 root_,
        uint256 watcherPrivateKey_
    ) internal {
        bytes32 digest = keccak256(
            abi.encode(
                switchboardAddress,
                dstSlug,
                packetId_,
                proposalCount_,
                root_
            )
        );

        // generate attest-signature
        bytes memory attestSignature = _createSignature(
            digest,
            watcherPrivateKey_
        );

        // attest with packetId_, srcSlug and signature
        FastSwitchboard(switchboardAddress).attest(
            packetId_,
            proposalCount_,
            root_,
            attestSignature
        );
    }

    function _signAndPropose(
        ChainContext storage cc_,
        bytes32 packetId_,
        bytes32 root_
    ) internal {
        bytes32 digest = keccak256(
            abi.encode(versionHash, cc_.chainSlug, packetId_, root_)
        );
        bytes memory sig_ = _createSignature(digest, _transmitterPrivateKey);
        _proposeOnDst(cc_, sig_, packetId_, root_, address(cc_.switchboard__));
    }

    function _executePayloadOnDstWithExecutor(
        ChainContext storage dst_,
        uint256 executorPrivateKey_,
        ExecutePayloadOnDstParams memory executionParams
    ) internal {
        ISocket.MessageDetails memory msgDetails = ISocket.MessageDetails(
            executionParams.msgId_,
            executionParams.executionFee_,
            executionParams.minMsgGasLimit_,
            executionParams.executionParams_,
            executionParams.payload_
        );

        bytes memory sig = _createSignature(
            executionParams.packedMessage_,
            executorPrivateKey_
        );

        (uint8 paramType, uint248 paramValue) = _decodeExecutionParams(
            executionParams.executionParams_
        );

        ISocket.ExecutionDetails memory executionDetails = ISocket
            .ExecutionDetails(
                executionParams.packetId_,
                executionParams.proposalCount_,
                executionParams.minMsgGasLimit_,
                executionParams.proof_,
                sig
            );

        if (paramType == 0) dst_.socket__.execute(executionDetails, msgDetails);
        else
            dst_.socket__.execute{value: paramValue}(
                executionDetails,
                msgDetails
            );
    }

    function _executePayloadOnDst(
        ChainContext storage dst_,
        ExecutePayloadOnDstParams memory executionParams
    ) internal {
        _executePayloadOnDstWithExecutor(
            dst_,
            _executorPrivateKey,
            executionParams
        );
    }

    function _executePayloadOnDstWithDiffLimit(
        uint256 executionMsgGasLimit_,
        ChainContext storage dst_,
        ExecutePayloadOnDstParams memory executionParams
    ) internal {
        ISocket.MessageDetails memory msgDetails = ISocket.MessageDetails(
            executionParams.msgId_,
            executionParams.executionFee_,
            executionParams.minMsgGasLimit_,
            executionParams.executionParams_,
            executionParams.payload_
        );

        bytes memory sig = _createSignature(
            executionParams.packedMessage_,
            _executorPrivateKey
        );

        (uint8 paramType, uint248 paramValue) = _decodeExecutionParams(
            executionParams.executionParams_
        );

        ISocket.ExecutionDetails memory executionDetails = ISocket
            .ExecutionDetails(
                executionParams.packetId_,
                executionParams.proposalCount_,
                executionMsgGasLimit_,
                executionParams.proof_,
                sig
            );

        if (paramType == 0) dst_.socket__.execute(executionDetails, msgDetails);
        else
            dst_.socket__.execute{value: paramValue}(
                executionDetails,
                msgDetails
            );
    }

    function _packMessageId(
        uint32 srcChainSlug_,
        address siblingPlug_,
        uint256 globalMessageCount_
    ) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(srcChainSlug_) << 224) |
                    (uint256(uint160(siblingPlug_)) << 64) |
                    globalMessageCount_
            );
    }

    function _getPackedId(
        address capacitorAddr_,
        uint32 srcChainSlug_,
        uint256 packetCount_
    ) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(srcChainSlug_) << 224) |
                    (uint256(uint160(capacitorAddr_)) << 64) |
                    packetCount_
            );
    }

    function _decodeExecutionParams(
        bytes32 executionParams_
    ) internal pure returns (uint8 paramType, uint248 paramValue) {
        paramType = uint8(uint256(executionParams_) >> 248);
        paramValue = uint248(uint256(executionParams_));
    }

    function test() external {
        initialize();
        _a.chainSlug = uint32(uint256(aChainSlug));
        _deploySocket(_a, _socketOwner, isExecutionOpen);

        SingleCapacitor capacitor = _a.socket__.capacitor();

        (
            bytes32 root,
            bytes32 packetId,
            bytes memory sig
        ) = _getLatestSignature(address(capacitor));

        bytes32 msgId = _packMessageId(_a.chainSlug, address(12345), 10);

        hoax(_socketOwner);
        _a.socket__.execute(
            ISocket.ExecutionDetails(
                packetId,
                uint256(0),
                uint256(100000),
                bytes(""),
                sig
            ),
            ISocket.MessageDetails(
                msgId,
                1 ether,
                uint256(100000),
                bytes32(0),
                bytes("random")
            )
        );

        hoax(_socketOwner);
        _a.socket__.seal(1, address(capacitor), sig);

        hoax(_socketOwner);
        _a.socket__.proposeForSwitchboard(
            packetId,
            root,
            address(_a.switchboard__),
            sig
        );

        hoax(_socketOwner);
        _a.switchboard__.attest(packetId, 0, root, sig);
    }
}

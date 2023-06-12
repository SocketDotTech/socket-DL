// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISocket, SocketConfig, SocketBase} from "../contracts/socket/SocketBase.sol";
import {Socket, SocketSrc, SocketDst} from "../contracts/socket/Socket.sol";
import "../contracts/utils/SignatureVerifier.sol";
import "../contracts/utils/Hasher.sol";

import "../contracts/switchboard/default-switchboards/FastSwitchboard.sol";
import "../contracts/switchboard/default-switchboards/OptimisticSwitchboard.sol";

import "../contracts/TransmitManager.sol";
import "../contracts/ExecutionManager.sol";
import "../contracts/OpenExecutionManager.sol";
import "../contracts/CapacitorFactory.sol";
import "../contracts/utils/AccessRoles.sol";
import "../contracts/utils/SigIdentifiers.sol";

contract Setup is Test {
    uint256 internal c = 1;
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

    address _feesPayer;
    address _feesWithdrawer;

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

    uint256 immutable _feesPayerPrivateKey = c++;
    uint256 immutable _feesWithdrawerPrivateKey = c++;

    uint256 _socketOwnerNonce;

    uint256 internal _timeoutInSeconds = 0;
    uint256 internal _slowCapacitorWaitTime = 300;
    uint256 internal _msgGasLimit = 30548;
    uint256 internal _transmissionFees = 350000000000;
    uint256 internal _executionFees = 110000000000;
    uint256 internal _msgValueMaxThreshold = 1000;
    uint256 internal _msgValueMinThreshold = 10;
    uint256 internal _relativeNativeTokenPrice = 1000 * 1e18;

    uint256 internal _executionOverhead = 50000;
    uint256 internal _capacitorType = 1;
    uint256 internal constant DEFAULT_BATCH_LENGTH = 1;

    bool isExecutionOpen = false;

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
        Socket socket__;
        Hasher hasher__;
        SignatureVerifier sigVerifier__;
        CapacitorFactory capacitorFactory__;
        TransmitManager transmitManager__;
        ExecutionManager executionManager__;
        SocketConfigContext[] configs__;
    }

    struct ExecutePayloadOnDstParams {
        bytes32 packetId_;
        uint256 proposalCount_;
        bytes32 msgId_;
        uint256 msgGasLimit_;
        bytes32 extraParams_;
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

    function initialise() internal {
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

        _feesPayer = vm.addr(_feesPayerPrivateKey);
        _feesWithdrawer = vm.addr(_feesWithdrawerPrivateKey);
    }

    function _dualChainSetup(
        uint256[] memory transmitterPrivateKeys_
    ) internal {
        initialise();
        _a.chainSlug = uint32(uint256(aChainSlug));
        _b.chainSlug = uint32(uint256(bChainSlug));

        _deployContractsOnSingleChain(
            _a,
            _b.chainSlug,
            isExecutionOpen,
            transmitterPrivateKeys_
        );
        _deployContractsOnSingleChain(
            _b,
            _a.chainSlug,
            isExecutionOpen,
            transmitterPrivateKeys_
        );
    }

    function _deployContractsOnSingleChain(
        ChainContext storage cc_,
        uint32 remoteChainSlug_,
        bool isExecutionOpen_,
        uint256[] memory transmitterPrivateKeys_
    ) internal {
        // deploy socket setup
        _deploySocket(cc_, _socketOwner, isExecutionOpen_);

        vm.startPrank(_socketOwner);
        _grantOwnerTransmitManagerRoles(cc_);
        _grantOwnerExecutionManagerRoles(cc_);
        _grantOwnerSocketRoles(cc_);

        //grant FeesUpdater Role
        cc_.transmitManager__.grantRoleWithSlug(
            FEES_UPDATER_ROLE,
            remoteChainSlug_,
            _socketOwner
        );

        //grant FeesUpdater Role
        cc_.executionManager__.grantRoleWithSlug(
            FEES_UPDATER_ROLE,
            remoteChainSlug_,
            _socketOwner
        );

        cc_.executionManager__.grantRoleWithSlug(
            FEES_UPDATER_ROLE,
            cc_.chainSlug,
            _socketOwner
        );

        _setTransmissionFees(cc_, remoteChainSlug_, _transmissionFees);
        _setExecutionFees(cc_, remoteChainSlug_, _executionFees);
        _setMsgValueMaxThreshold(cc_, remoteChainSlug_, _msgValueMaxThreshold);
        _setRelativeNativeTokenPrice(
            cc_,
            remoteChainSlug_,
            _relativeNativeTokenPrice
        );
        vm.stopPrank();

        // deploy default configs: fast, slow
        SocketConfigContext memory scc_ = _addFastSwitchboard(
            cc_,
            remoteChainSlug_,
            _capacitorType
        );
        cc_.configs__.push(scc_);

        scc_ = _addOptimisticSwitchboard(cc_, remoteChainSlug_, _capacitorType);
        cc_.configs__.push(scc_);

        // add roles
        hoax(_socketOwner);
        cc_.executionManager__.grantRole(EXECUTOR_ROLE, _executor);

        _addTransmitters(transmitterPrivateKeys_, cc_, remoteChainSlug_);
        _addTransmitters(transmitterPrivateKeys_, cc_, cc_.chainSlug);

        _testUtils(_a);
    }

    function _grantOwnerSocketRoles(ChainContext storage cc_) internal {
        cc_.socket__.grantRole(RESCUE_ROLE, _socketOwner);
        cc_.socket__.grantRole(GOVERNANCE_ROLE, _socketOwner);
    }

    function _grantOwnerTransmitManagerRoles(
        ChainContext storage cc_
    ) internal {
        cc_.transmitManager__.grantRole(RESCUE_ROLE, _socketOwner);
        cc_.transmitManager__.grantRole(WITHDRAW_ROLE, _socketOwner);
        cc_.transmitManager__.grantRole(GOVERNANCE_ROLE, _socketOwner);
    }

    function _grantOwnerExecutionManagerRoles(
        ChainContext storage cc_
    ) internal {
        cc_.executionManager__.grantRole(RESCUE_ROLE, _socketOwner);
        cc_.executionManager__.grantRole(WITHDRAW_ROLE, _socketOwner);
        cc_.executionManager__.grantRole(EXECUTOR_ROLE, _executor);
    }

    function _setTransmissionFees(
        ChainContext storage cc_,
        uint32 remoteChainSlug_,
        uint256 transmissionFees_
    ) internal {
        //set TransmissionFees for remoteChainSlug
        bytes32 feesUpdateDigest = keccak256(
            abi.encode(
                FEES_UPDATE_SIG_IDENTIFIER,
                address(cc_.transmitManager__),
                cc_.chainSlug,
                remoteChainSlug_,
                cc_.transmitterNonce,
                transmissionFees_
            )
        );

        bytes memory feesUpdateSignature = _createSignature(
            feesUpdateDigest,
            _socketOwnerPrivateKey
        );
        cc_.transmitManager__.setTransmissionFees(
            cc_.transmitterNonce++,
            uint32(remoteChainSlug_),
            transmissionFees_,
            feesUpdateSignature
        );
    }

    function _setExecutionFees(
        ChainContext storage cc_,
        uint32 remoteChainSlug_,
        uint256 executionFees_
    ) internal {
        //set ExecutionFees for remoteChainSlug
        bytes32 feesUpdateDigest = keccak256(
            abi.encode(
                FEES_UPDATE_SIG_IDENTIFIER,
                address(cc_.executionManager__),
                cc_.chainSlug,
                remoteChainSlug_,
                cc_.executorNonce,
                executionFees_
            )
        );

        bytes memory feesUpdateSignature = _createSignature(
            feesUpdateDigest,
            _socketOwnerPrivateKey
        );

        cc_.executionManager__.setExecutionFees(
            cc_.executorNonce++,
            uint32(remoteChainSlug_),
            executionFees_,
            feesUpdateSignature
        );
    }

    function _setMsgValueMaxThreshold(
        ChainContext storage cc_,
        uint32 remoteChainSlug_,
        uint256 threshold
    ) internal {
        //set ExecutionFees for remoteChainSlug
        bytes32 feesUpdateDigest = keccak256(
            abi.encode(
                MSG_VALUE_MAX_THRESHOLD_SIG_IDENTIFIER,
                address(cc_.executionManager__),
                cc_.chainSlug,
                remoteChainSlug_,
                cc_.executorNonce,
                threshold
            )
        );

        bytes memory feesUpdateSignature = _createSignature(
            feesUpdateDigest,
            _socketOwnerPrivateKey
        );

        cc_.executionManager__.setMsgValueMaxThreshold(
            cc_.executorNonce++,
            uint32(remoteChainSlug_),
            threshold,
            feesUpdateSignature
        );
    }

    function _setMsgValueMinThreshold(
        ChainContext storage cc_,
        uint32 remoteChainSlug_,
        uint256 threshold
    ) internal {
        //set ExecutionFees for remoteChainSlug
        bytes32 feesUpdateDigest = keccak256(
            abi.encode(
                MSG_VALUE_MIN_THRESHOLD_SIG_IDENTIFIER,
                address(cc_.executionManager__),
                cc_.chainSlug,
                remoteChainSlug_,
                cc_.executorNonce,
                threshold
            )
        );

        bytes memory feesUpdateSignature = _createSignature(
            feesUpdateDigest,
            _socketOwnerPrivateKey
        );

        cc_.executionManager__.setMsgValueMinThreshold(
            cc_.executorNonce++,
            uint32(remoteChainSlug_),
            threshold,
            feesUpdateSignature
        );
    }

    function _setMsgValueMinThreshold(
        ChainContext storage cc_,
        uint256 threshold
    ) internal {
        //set ExecutionFees for remoteChainSlug
        bytes32 feesUpdateDigest = keccak256(
            abi.encode(
                MSG_VALUE_MIN_THRESHOLD_SIG_IDENTIFIER,
                address(cc_.executionManager__),
                aChainSlug,
                bChainSlug,
                cc_.executorNonce,
                threshold
            )
        );

        bytes memory feesUpdateSignature = _createSignature(
            feesUpdateDigest,
            _socketOwnerPrivateKey
        );

        cc_.executionManager__.setMsgValueMinThreshold(
            cc_.executorNonce++,
            uint32(bChainSlug),
            threshold,
            feesUpdateSignature
        );
    }

    function _setRelativeNativeTokenPrice(
        ChainContext storage cc_,
        uint32 remoteChainSlug_,
        uint256 relativePrice
    ) internal {
        //set ExecutionFees for remoteChainSlug
        bytes32 feesUpdateDigest = keccak256(
            abi.encode(
                RELATIVE_NATIVE_TOKEN_PRICE_UPDATE_SIG_IDENTIFIER,
                address(cc_.executionManager__),
                cc_.chainSlug,
                remoteChainSlug_,
                cc_.executorNonce,
                relativePrice
            )
        );

        bytes memory feesUpdateSignature = _createSignature(
            feesUpdateDigest,
            _socketOwnerPrivateKey
        );

        cc_.executionManager__.setRelativeNativeTokenPrice(
            cc_.executorNonce++,
            uint32(remoteChainSlug_),
            relativePrice,
            feesUpdateSignature
        );
    }

    function _addOptimisticSwitchboard(
        ChainContext storage cc_,
        uint32 remoteChainSlug_,
        uint256 capacitorType_
    ) internal returns (SocketConfigContext memory scc_) {
        OptimisticSwitchboard optimisticSwitchboard = new OptimisticSwitchboard(
            _socketOwner,
            address(cc_.socket__),
            cc_.chainSlug,
            _timeoutInSeconds,
            cc_.sigVerifier__
        );

        uint256 nonce = 0;
        hoax(_socketOwner);
        optimisticSwitchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);

        scc_ = _registerSwitchboard(
            cc_,
            _socketOwner,
            address(optimisticSwitchboard),
            nonce,
            remoteChainSlug_,
            capacitorType_
        );
    }

    function _addFastSwitchboard(
        ChainContext storage cc_,
        uint32 remoteChainSlug_,
        uint256 capacitorType_
    ) internal returns (SocketConfigContext memory scc_) {
        FastSwitchboard fastSwitchboard = new FastSwitchboard(
            _socketOwner,
            address(cc_.socket__),
            cc_.chainSlug,
            _timeoutInSeconds,
            cc_.sigVerifier__
        );
        uint256 nonce = 0;

        vm.startPrank(_socketOwner);
        fastSwitchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);
        fastSwitchboard.grantWatcherRole(remoteChainSlug_, _watcher);
        vm.stopPrank();

        scc_ = _registerSwitchboard(
            cc_,
            _socketOwner,
            address(fastSwitchboard),
            nonce,
            remoteChainSlug_,
            capacitorType_
        );
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

        cc_.capacitorFactory__ = new CapacitorFactory(deployer_);

        if (isExecutionOpen_) {
            cc_.executionManager__ = new OpenExecutionManager(
                deployer_,
                cc_.chainSlug,
                cc_.sigVerifier__
            );
        } else {
            cc_.executionManager__ = new ExecutionManager(
                deployer_,
                cc_.chainSlug,
                cc_.sigVerifier__
            );
        }

        cc_.transmitManager__ = new TransmitManager(
            cc_.sigVerifier__,
            deployer_,
            cc_.chainSlug
        );

        cc_.socket__ = new Socket(
            uint32(cc_.chainSlug),
            address(cc_.hasher__),
            address(cc_.transmitManager__),
            address(cc_.executionManager__),
            address(cc_.capacitorFactory__),
            deployer_,
            version
        );

        vm.stopPrank();
    }

    function _registerSwitchboard(
        ChainContext storage cc_,
        address governance_,
        address switchBoardAddress_,
        uint256 nonce_,
        uint32 remoteChainSlug_,
        uint256 capacitorType_
    ) internal returns (SocketConfigContext memory scc_) {
        scc_.switchboard__ = ISwitchboard(switchBoardAddress_);

        hoax(_raju);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                GOVERNANCE_ROLE
            )
        );
        scc_.switchboard__.registerSiblingSlug(
            uint32(remoteChainSlug_),
            DEFAULT_BATCH_LENGTH,
            capacitorType_
        );

        hoax(governance_);
        scc_.switchboard__.registerSiblingSlug(
            uint32(remoteChainSlug_),
            DEFAULT_BATCH_LENGTH,
            capacitorType_
        );

        scc_.siblingChainSlug = remoteChainSlug_;
        scc_.switchboardNonce = nonce_;
        scc_.capacitor__ = cc_.socket__.capacitors__(
            switchBoardAddress_,
            remoteChainSlug_
        );
        scc_.decapacitor__ = cc_.socket__.decapacitors__(
            switchBoardAddress_,
            remoteChainSlug_
        );
    }

    function sealAndPropose(
        address capacitor
    ) internal returns (bytes32 packetId_, bytes32 root_) {
        bytes memory sig_;
        (root_, packetId_, sig_) = _getLatestSignature(
            capacitor,
            _a.chainSlug,
            _b.chainSlug
        );

        _sealOnSrc(_a, capacitor, sig_);
        _proposeOnDst(_b, sig_, packetId_, root_);
    }

    function _addTransmitters(
        uint256[] memory transmitterPrivateKeys_,
        ChainContext memory cc_,
        uint32 remoteChainSlug_
    ) internal {
        vm.startPrank(_socketOwner);

        address transmitter;
        for (
            uint256 index = 0;
            index < transmitterPrivateKeys_.length;
            index++
        ) {
            // deduce transmitter address from private key
            transmitter = vm.addr(transmitterPrivateKeys_[index]);
            // grant transmitter role
            cc_.transmitManager__.grantRoleWithSlug(
                TRANSMITTER_ROLE,
                remoteChainSlug_,
                transmitter
            );
        }

        vm.stopPrank();
    }

    function _getLatestSignature(
        address capacitor_,
        uint32 srcChainSlug_,
        uint32 remoteChainSlug_
    ) internal returns (bytes32 root, bytes32 packetId, bytes memory sig) {
        uint64 id;
        (root, id) = ICapacitor(capacitor_).getNextPacketToBeSealed();
        packetId = _getPackedId(capacitor_, srcChainSlug_, id);
        bytes32 digest = keccak256(
            abi.encode(versionHash, remoteChainSlug_, packetId, root)
        );
        sig = _createSignature(digest, _transmitterPrivateKey);
    }

    function _createSignature(
        bytes32 digest_,
        uint256 privateKey_
    ) internal returns (bytes memory sig) {
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
        bytes memory sig_
    ) internal {
        src_.socket__.seal(DEFAULT_BATCH_LENGTH, capacitor, sig_);

        // random capacitor
        address randomCapacitor = address(uint160(c++));
        vm.expectRevert();
        src_.socket__.seal(DEFAULT_BATCH_LENGTH, randomCapacitor, sig_);

        // non-socket capacitor
        SingleCapacitor randomCapacitor__ = new SingleCapacitor(
            address(src_.socket__),
            _socketOwner
        );
        hoax(address(src_.socket__));
        randomCapacitor__.addPackedMessage(bytes32("random"));

        vm.expectRevert(SocketSrc.InvalidCapacitor.selector);
        src_.socket__.seal(
            DEFAULT_BATCH_LENGTH,
            address(randomCapacitor__),
            sig_
        );
    }

    function _proposeOnDst(
        ChainContext storage dst_,
        bytes memory sig_,
        bytes32 packetId_,
        bytes32 root_
    ) internal {
        dst_.socket__.propose(packetId_, root_, sig_);

        vm.expectRevert(SocketDst.InvalidPacketId.selector);
        dst_.socket__.propose(bytes32(0), root_, sig_);
    }

    function _attestOnDst(
        address switchboardAddress,
        uint32 dstSlug,
        bytes32 packetId_,
        uint256 proposalCount_,
        uint256 watcherPrivateKey_
    ) internal {
        bytes32 digest = keccak256(
            abi.encode(switchboardAddress, dstSlug, packetId_, proposalCount_)
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
            attestSignature
        );
    }

    function _executePayloadOnDstWithExecutor(
        ChainContext storage dst_,
        uint256 executorPrivateKey_,
        ExecutePayloadOnDstParams memory executionParams
    ) internal {
        ISocket.MessageDetails memory msgDetails = ISocket.MessageDetails(
            executionParams.msgId_,
            executionParams.executionFee_,
            executionParams.msgGasLimit_,
            executionParams.extraParams_,
            executionParams.payload_,
            executionParams.proof_
        );

        bytes memory sig = _createSignature(
            executionParams.packedMessage_,
            executorPrivateKey_
        );

        (uint8 paramType, uint248 paramValue) = _decodeExtraParams(
            executionParams.extraParams_
        );
        if (paramType == 0)
            dst_.socket__.execute(
                executionParams.packetId_,
                executionParams.proposalCount_,
                msgDetails,
                sig
            );
        else
            dst_.socket__.execute{value: paramValue}(
                executionParams.packetId_,
                executionParams.proposalCount_,
                msgDetails,
                sig
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

    function _testUtils(ChainContext storage cc_) internal {
        uint256 amount = 1e18;

        hoax(_socketOwner);
        _rescueNative(
            address(cc_.hasher__),
            NATIVE_TOKEN_ADDRESS,
            _fundRescuer,
            amount
        );

        hoax(_socketOwner);
        _rescueNative(
            address(cc_.sigVerifier__),
            NATIVE_TOKEN_ADDRESS,
            _fundRescuer,
            amount
        );
    }

    function _rescueNative(
        address contractAddress,
        address token,
        address to,
        uint256 amount
    ) internal {
        uint256 initialBal = to.balance;

        assertEq(address(contractAddress).balance, 0);
        deal(address(contractAddress), amount);
        assertEq(address(contractAddress).balance, amount);

        Socket(contractAddress).rescueFunds(token, to, amount);

        assertEq(to.balance, initialBal + amount);
        assertEq(address(contractAddress).balance, 0);
    }

    function _packMessageId(
        uint32 srcChainSlug_,
        address siblingPlug_,
        uint256 messageCount_
    ) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(srcChainSlug_) << 224) |
                    (uint256(uint160(siblingPlug_)) << 64) |
                    messageCount_
            );
    }

    function _getPackedId(
        address capacitorAddr_,
        uint32 chainSlug_,
        uint256 id_
    ) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(chainSlug_) << 224) |
                    (uint256(uint160(capacitorAddr_)) << 64) |
                    id_
            );
    }

    function _decodeExtraParams(
        bytes32 extraParams_
    ) internal pure returns (uint8 paramType, uint248 paramValue) {
        paramType = uint8(uint256(extraParams_) >> 248);
        paramValue = uint248(uint256(extraParams_));
    }

    // to ignore this file from coverage
    function test() external {
        assertTrue(true);
    }
}

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
import "../contracts/GasPriceOracle.sol";
import "../contracts/ExecutionManager.sol";
import "../contracts/CapacitorFactory.sol";
import "../contracts/utils/AccessRoles.sol";
import "../contracts/utils/SigIdentifiers.sol";

contract Setup is Test {
    uint256 internal c = 1;
    address immutable _plugOwner = address(uint160(c++));
    address immutable _raju = address(uint160(c++));

    string version = "TEST_NET";

    bytes32 versionHash = keccak256(abi.encode(version));

    uint256 immutable executorPrivateKey = c++;
    uint256 immutable _socketOwnerPrivateKey = c++;

    address _socketOwner;
    address _executor;
    address _transmitter;
    address _altTransmitter;

    address _watcher;
    address _altWatcher;

    uint256 immutable _transmitterPrivateKey = c++;
    uint256 immutable _watcherPrivateKey = c++;

    uint256 immutable _altTransmitterPrivateKey = c++;
    uint256 immutable _altWatcherPrivateKey = c++;

    uint256 internal _timeoutInSeconds = 0;
    uint256 internal _slowCapacitorWaitTime = 300;
    uint256 internal _msgGasLimit = 30548;
    uint256 internal _sealGasLimit = 150000;
    uint256 internal _proposeGasLimit = 150000;
    uint256 internal _attestGasLimit = 150000;
    uint256 internal _executionOverhead = 50000;
    uint256 internal _capacitorType = 1;
    uint256 internal constant DEFAULT_BATCH_LENGTH = 1;
    uint256 gasPriceOracleNonce;

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
        Socket socket__;
        Hasher hasher__;
        SignatureVerifier sigVerifier__;
        CapacitorFactory capacitorFactory__;
        TransmitManager transmitManager__;
        GasPriceOracle gasPriceOracle__;
        ExecutionManager executionManager__;
        SocketConfigContext[] configs__;
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
        _watcher = vm.addr(_watcherPrivateKey);
        _transmitter = vm.addr(_transmitterPrivateKey);
        _executor = vm.addr(executorPrivateKey);
    }

    function _dualChainSetup(
        uint256[] memory transmitterPrivateKeys_
    ) internal {
        initialise();
        _a.chainSlug = uint32(uint256(0x2013AA263));
        _b.chainSlug = uint32(uint256(0x2013AA264));

        _deployContractsOnSingleChain(
            _a,
            _b.chainSlug,
            transmitterPrivateKeys_
        );
        _deployContractsOnSingleChain(
            _b,
            _a.chainSlug,
            transmitterPrivateKeys_
        );
    }

    function _deployContractsOnSingleChain(
        ChainContext storage cc_,
        uint32 remoteChainSlug_,
        uint256[] memory transmitterPrivateKeys_
    ) internal {
        // deploy socket setup
        _deploySocket(cc_, _socketOwner);

        vm.startPrank(_socketOwner);

        cc_.transmitManager__.grantRoleWithSlug(
            GAS_LIMIT_UPDATER_ROLE,
            remoteChainSlug_,
            _socketOwner
        );

        vm.stopPrank();

        bytes32 digest = keccak256(
            abi.encode(
                PROPOSE_GAS_LIMIT_UPDATE_SIG_IDENTIFIER,
                address(cc_.transmitManager__),
                cc_.chainSlug,
                remoteChainSlug_,
                cc_.transmitterNonce,
                _proposeGasLimit
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);
        cc_.transmitManager__.setProposeGasLimit(
            cc_.transmitterNonce++,
            remoteChainSlug_,
            _proposeGasLimit,
            sig
        );

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
    }

    function _addOptimisticSwitchboard(
        ChainContext storage cc_,
        uint32 remoteChainSlug_,
        uint256 capacitorType_
    ) internal returns (SocketConfigContext memory scc_) {
        OptimisticSwitchboard optimisticSwitchboard = new OptimisticSwitchboard(
            _socketOwner,
            address(cc_.socket__),
            address(cc_.gasPriceOracle__),
            cc_.chainSlug,
            _timeoutInSeconds
        );

        uint256 nonce = 0;
        vm.startPrank(_socketOwner);

        optimisticSwitchboard.grantRoleWithSlug(
            GAS_LIMIT_UPDATER_ROLE,
            remoteChainSlug_,
            _socketOwner
        );

        bytes32 digest = keccak256(
            abi.encode(
                EXECUTION_OVERHEAD_UPDATE_SIG_IDENTIFIER,
                address(optimisticSwitchboard),
                cc_.chainSlug,
                remoteChainSlug_,
                nonce,
                _executionOverhead
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        optimisticSwitchboard.setExecutionOverhead(
            nonce++,
            remoteChainSlug_,
            _executionOverhead,
            sig
        );
        optimisticSwitchboard.grantRoleWithSlug(
            WATCHER_ROLE,
            remoteChainSlug_,
            _watcher
        );

        vm.stopPrank();

        scc_ = _registerSwitchbaord(
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
            address(cc_.gasPriceOracle__),
            cc_.chainSlug,
            _timeoutInSeconds
        );
        uint256 nonce = 0;

        vm.startPrank(_socketOwner);
        fastSwitchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);
        fastSwitchboard.grantRoleWithSlug(
            GAS_LIMIT_UPDATER_ROLE,
            remoteChainSlug_,
            _socketOwner
        );
        fastSwitchboard.grantWatcherRole(remoteChainSlug_, _watcher);

        vm.stopPrank();

        bytes32 digest = keccak256(
            abi.encode(
                EXECUTION_OVERHEAD_UPDATE_SIG_IDENTIFIER,
                address(fastSwitchboard),
                cc_.chainSlug,
                remoteChainSlug_,
                nonce,
                _executionOverhead
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        fastSwitchboard.setExecutionOverhead(
            nonce++,
            remoteChainSlug_,
            _executionOverhead,
            sig
        );

        digest = keccak256(
            abi.encode(
                ATTEST_GAS_LIMIT_UPDATE_SIG_IDENTIFIER,
                address(fastSwitchboard),
                cc_.chainSlug,
                remoteChainSlug_,
                nonce,
                _attestGasLimit
            )
        );
        sig = _createSignature(digest, _socketOwnerPrivateKey);

        fastSwitchboard.setAttestGasLimit(
            nonce++,
            remoteChainSlug_,
            _attestGasLimit,
            sig
        );

        scc_ = _registerSwitchbaord(
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
        address deployer_
    ) internal {
        vm.startPrank(deployer_);

        cc_.hasher__ = new Hasher();
        cc_.sigVerifier__ = new SignatureVerifier();
        cc_.capacitorFactory__ = new CapacitorFactory(deployer_);
        cc_.gasPriceOracle__ = new GasPriceOracle(deployer_, cc_.chainSlug);
        cc_.executionManager__ = new ExecutionManager(
            cc_.gasPriceOracle__,
            deployer_
        );

        cc_.gasPriceOracle__.grantRole(GOVERNANCE_ROLE, deployer_);
        cc_.gasPriceOracle__.grantRole(GAS_LIMIT_UPDATER_ROLE, deployer_);

        cc_.transmitManager__ = new TransmitManager(
            cc_.sigVerifier__,
            cc_.gasPriceOracle__,
            deployer_,
            cc_.chainSlug,
            _sealGasLimit
        );

        cc_.transmitManager__.grantRoleWithSlug(
            GAS_LIMIT_UPDATER_ROLE,
            cc_.chainSlug,
            deployer_
        );

        cc_.gasPriceOracle__.setTransmitManager(cc_.transmitManager__);

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

    function _registerSwitchbaord(
        ChainContext storage cc_,
        address deployer_,
        address switchBoardAddress_,
        uint256 nonce_,
        uint32 remoteChainSlug_,
        uint256 capacitorType_
    ) internal returns (SocketConfigContext memory scc_) {
        vm.startPrank(deployer_);
        cc_.socket__.registerSwitchBoard(
            switchBoardAddress_,
            DEFAULT_BATCH_LENGTH,
            uint32(remoteChainSlug_),
            uint32(capacitorType_)
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
        scc_.switchboard__ = ISwitchboard(switchBoardAddress_);

        vm.stopPrank();
    }

    function sealAndPropose(
        address capacitor
    ) internal returns (bytes32 packetId_, bytes32 root_) {
        bytes memory sig_;
        (root_, packetId_, sig_) = _getLatestSignature(
            _a,
            capacitor,
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
        ChainContext storage src_,
        address capacitor_,
        uint32 remoteChainSlug_
    ) internal returns (bytes32 root, bytes32 packetId, bytes memory sig) {
        uint64 id;
        (root, id) = ICapacitor(capacitor_).getNextPacketToBeSealed();
        packetId = _getPackedId(capacitor_, src_.chainSlug, id);
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
        hoax(_raju);
        src_.socket__.seal(DEFAULT_BATCH_LENGTH, capacitor, sig_);
    }

    function _proposeOnDst(
        ChainContext storage dst_,
        bytes memory sig_,
        bytes32 packetId_,
        bytes32 root_
    ) internal {
        hoax(_raju);
        dst_.socket__.propose(packetId_, root_, sig_);
    }

    function _attestOnDst(
        address switchboardAddress,
        uint32 dstSlug,
        bytes32 packetId_
    ) internal {
        uint32 srcSlug = uint32(uint256(packetId_) >> 224);
        bytes32 digest = keccak256(
            abi.encode(switchboardAddress, srcSlug, dstSlug, packetId_)
        );

        // generate attest-signature
        bytes memory attestSignature = _createSignature(
            digest,
            _watcherPrivateKey
        );

        // attest with packetId_, srcSlug and signature
        FastSwitchboard(switchboardAddress).attest(
            packetId_,
            srcSlug,
            attestSignature
        );
    }

    function _executePayloadOnDstWithExecutor(
        ChainContext storage dst_,
        bytes32 packetId_,
        bytes32 msgId_,
        uint256 msgGasLimit_,
        uint256 executionFee_,
        bytes32 packedMessage_,
        uint256 executorPrivateKey_,
        bytes memory payload_,
        bytes memory proof_
    ) internal {
        ISocket.MessageDetails memory msgDetails = ISocket.MessageDetails(
            msgId_,
            executionFee_,
            msgGasLimit_,
            payload_,
            proof_
        );

        bytes memory sig = _createSignature(
            packedMessage_,
            executorPrivateKey_
        );
        dst_.socket__.execute(packetId_, msgDetails, sig);
    }

    function _executePayloadOnDst(
        ChainContext storage dst_,
        uint256,
        bytes32 packetId_,
        bytes32 msgId_,
        uint256 msgGasLimit_,
        uint256 executionFee_,
        bytes32 packedMessage_,
        bytes memory payload_,
        bytes memory proof_
    ) internal {
        _executePayloadOnDstWithExecutor(
            dst_,
            packetId_,
            msgId_,
            msgGasLimit_,
            executionFee_,
            packedMessage_,
            executorPrivateKey,
            payload_,
            proof_
        );
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

    // to ignore this file from coverage
    function test() external {
        assertTrue(true);
    }
}

// SPDX-License-Identifier: UNLICENSED
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

contract Setup is Test {
    uint256 internal c = 1;
    address immutable _socketOwner = address(uint160(c++));
    address immutable _plugOwner = address(uint160(c++));
    address immutable _raju = address(uint160(c++));
    address immutable _executor = address(uint160(c++));

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
    bytes32 internal EXECUTOR_ROLE =
        0x9cf85f95575c3af1e116e3d37fd41e7f36a8a373623f51ffaaa87fdd032fa767;
    uint256 internal constant DEFAULT_BATCH_LENGTH = 0;

    struct SocketConfigContext {
        uint256 siblingChainSlug;
        ICapacitor capacitor__;
        IDecapacitor decapacitor__;
        ISwitchboard switchboard__;
    }

    struct ChainContext {
        uint256 chainSlug;
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

    function _dualChainSetup(
        uint256[] memory transmitterPrivateKeys_
    ) internal {
        _a.chainSlug = uint32(uint256(0x2013AA263));
        _b.chainSlug = uint32(uint256(0x2013AA264));

        _watcher = vm.addr(_watcherPrivateKey);
        _transmitter = vm.addr(_transmitterPrivateKey);

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
        uint256 remoteChainSlug_,
        uint256[] memory transmitterPrivateKeys_
    ) internal {
        // deploy socket setup
        _deploySocket(cc_, _socketOwner);

        hoax(_socketOwner);
        cc_.transmitManager__.setProposeGasLimit(
            remoteChainSlug_,
            _proposeGasLimit
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
    }

    function _addOptimisticSwitchboard(
        ChainContext storage cc_,
        uint256 remoteChainSlug_,
        uint256 capacitorType_
    ) internal returns (SocketConfigContext memory scc_) {
        OptimisticSwitchboard optimisticSwitchboard = new OptimisticSwitchboard(
            _socketOwner,
            address(cc_.gasPriceOracle__),
            _timeoutInSeconds
        );
        vm.startPrank(_socketOwner);

        optimisticSwitchboard.setExecutionOverhead(
            remoteChainSlug_,
            _executionOverhead
        );
        optimisticSwitchboard.grantRoleWithUint(remoteChainSlug_, _watcher);
        vm.stopPrank();

        scc_ = _registerSwitchbaord(
            cc_,
            _socketOwner,
            address(optimisticSwitchboard),
            remoteChainSlug_,
            capacitorType_
        );
    }

    function _addFastSwitchboard(
        ChainContext storage cc_,
        uint256 remoteChainSlug_,
        uint256 capacitorType_
    ) internal returns (SocketConfigContext memory scc_) {
        FastSwitchboard fastSwitchboard = new FastSwitchboard(
            _socketOwner,
            address(cc_.gasPriceOracle__),
            _timeoutInSeconds
        );

        vm.startPrank(_socketOwner);
        fastSwitchboard.setExecutionOverhead(
            remoteChainSlug_,
            _executionOverhead
        );
        fastSwitchboard.grantWatcherRole(remoteChainSlug_, _watcher);
        fastSwitchboard.setAttestGasLimit(remoteChainSlug_, _attestGasLimit);
        vm.stopPrank();

        scc_ = _registerSwitchbaord(
            cc_,
            _socketOwner,
            address(fastSwitchboard),
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
        cc_.capacitorFactory__ = new CapacitorFactory();
        cc_.gasPriceOracle__ = new GasPriceOracle(deployer_, cc_.chainSlug);
        cc_.executionManager__ = new ExecutionManager(
            cc_.gasPriceOracle__,
            deployer_
        );

        cc_.transmitManager__ = new TransmitManager(
            cc_.sigVerifier__,
            cc_.gasPriceOracle__,
            deployer_,
            cc_.chainSlug,
            _sealGasLimit
        );

        cc_.gasPriceOracle__.setTransmitManager(cc_.transmitManager__);

        cc_.socket__ = new Socket(
            uint32(cc_.chainSlug),
            address(cc_.hasher__),
            address(cc_.transmitManager__),
            address(cc_.executionManager__),
            address(cc_.capacitorFactory__)
        );

        vm.stopPrank();
    }

    function _registerSwitchbaord(
        ChainContext storage cc_,
        address deployer_,
        address switchBoardAddress_,
        uint256 remoteChainSlug_,
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

    function _addTransmitters(
        uint256[] memory transmitterPrivateKeys_,
        ChainContext memory cc_,
        uint256 remoteChainSlug_
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
            cc_.transmitManager__.grantRoleWithUint(
                remoteChainSlug_,
                transmitter
            );
        }

        vm.stopPrank();
    }

    function _getLatestSignature(
        ChainContext storage src_,
        address capacitor_,
        uint256 remoteChainSlug_
    ) internal returns (bytes32 root, uint256 packetId, bytes memory sig) {
        uint256 id;
        (root, id) = ICapacitor(capacitor_).getNextPacketToBeSealed();
        packetId = _getPackedId(capacitor_, src_.chainSlug, id);
        bytes32 digest = keccak256(
            abi.encode(remoteChainSlug_, packetId, root)
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
        uint256 packetId_,
        bytes32 root_
    ) internal {
        hoax(_raju);
        dst_.socket__.propose(packetId_, root_, sig_);
    }

    function _executePayloadOnDst(
        ChainContext storage dst_,
        uint256,
        address remotePlug_,
        uint256 packetId_,
        uint256 msgId_,
        uint256 msgGasLimit_,
        uint256 executionFee_,
        bytes memory payload_,
        bytes memory proof_
    ) internal {
        hoax(_executor);

        ISocket.MessageDetails memory msgDetails = ISocket.MessageDetails(
            msgId_,
            executionFee_,
            msgGasLimit_,
            payload_,
            proof_
        );

        dst_.socket__.execute(packetId_, remotePlug_, msgDetails);
    }

    function _packMessageId(
        uint256 srcChainSlug,
        uint256 nonce
    ) internal pure returns (uint256) {
        return (srcChainSlug << 224) | nonce;
    }

    function _getPackedId(
        address capacitorAddr_,
        uint256 chainSlug_,
        uint256 id_
    ) internal pure returns (uint256) {
        return
            (chainSlug_ << 224) |
            (uint256(uint160(capacitorAddr_)) << 64) |
            id_;
    }

    // to ignore this file from coverage
    function test() external {
        assertTrue(true);
    }
}

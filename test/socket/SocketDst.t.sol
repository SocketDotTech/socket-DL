// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../Setup.t.sol";
import "../../contracts/examples/Counter.sol";
import "../managers/ExecutionManager.t.sol";

contract SocketDstTest is Setup {
    Counter srcCounter__;
    Counter dstCounter__;

    uint256 addAmount = 100;
    uint256 subAmount = 40;

    address immutable _invalidExecutor = address(uint160(c++));

    bool isFast = true;
    uint256 index = isFast ? 0 : 1;

    bytes32[] roots;

    error AlreadyAttested();
    error InvalidTransmitter();
    error InsufficientFees();
    error NotExecutor();
    event ExecutionSuccess(bytes32 msgId);
    event ExecutionFailed(bytes32 msgId, string result);
    event ExecutionFailedBytes(bytes32 msgId, bytes result);
    error AlreadyProposed();
    error PacketNotProposed();
    error InvalidPacketRoot();
    error InvalidPacketId();

    event PacketVerifiedAndSealed(
        address indexed transmitter,
        bytes32 indexed packetId,
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

    event MessageTransmitted(
        uint32 localChainSlug,
        address localPlug,
        uint32 dstChainSlug,
        address dstPlug,
        bytes32 msgId,
        uint256 minMsgGasLimit,
        uint256 executionFee,
        uint256 fees,
        bytes payload
    );

    function setUp() external {
        uint256[] memory transmitterPrivateKeys = new uint256[](1);
        transmitterPrivateKeys[0] = _transmitterPrivateKey;

        _dualChainSetup(transmitterPrivateKeys);
        _deployPlugContracts();
        _configPlugContracts(index);

        // grant role to this contract to be able to call SocketDst
        vm.prank(_b.socket__.owner());
        _b.socket__.grantRole(SOCKET_RELAYER_ROLE, address(this));

        // grant role to this contract to be able to call SocketSrc
        vm.prank(_a.socket__.owner());
        _a.socket__.grantRole(SOCKET_RELAYER_ROLE, address(this));
        
        // grant role to SocketSrc to be able to call ExecutionManager
        vm.prank(_a.socket__.owner());
        _a.executionManager__.grantRole(SOCKET_RELAYER_ROLE, address(_a.socket__));
        
        // grant role to SrcCounter to be able to call SocketDst
        vm.prank(_b.socket__.owner());
        _b.socket__.grantRole(SOCKET_RELAYER_ROLE, address(srcCounter__));

        // grant role to SrcCounter to be able to call SocketSrc
        vm.prank(_a.socket__.owner());
        _a.socket__.grantRole(SOCKET_RELAYER_ROLE, address(srcCounter__));
    }

    function testProposeWithoutSocketRelayerRole() external {
        // revoke the SOCKET_RELAYER_ROLE
        vm.prank(_b.socket__.owner());
        _b.socket__.revokeRole(SOCKET_RELAYER_ROLE, address(this));

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                SOCKET_RELAYER_ROLE
            )
        );
        _b.socket__.proposeForSwitchboard(
            bytes32(0),
            bytes32(0),
            address(_b.configs__[0].switchboard__),
            bytes("")
        );
    }

    function testExecuteWithoutSocketRelayerRole() external {
        // revoke the SOCKET_RELAYER_ROLE
        vm.prank(_b.socket__.owner());
        _b.socket__.revokeRole(SOCKET_RELAYER_ROLE, address(this));

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                SOCKET_RELAYER_ROLE
            )
        );
        ISocket.ExecutionDetails memory executionDetails = ISocket.ExecutionDetails(
            bytes32(0),
            0,
            0,
            bytes(""),
            bytes("")
        );
        ISocket.MessageDetails memory msgDetails = ISocket.MessageDetails(
            bytes32(0),
            0,
            0,
            bytes32(0),
            bytes("")
        );
        _b.socket__.execute(executionDetails, msgDetails);
    }
    
    function testProposeAPacket() external {
        address capacitor = address(_a.configs__[index].capacitor__);
        sendOutboundMessage();

        (
            bytes32 root_,
            bytes32 packetId_,
            bytes memory sig_
        ) = getLatestSignature(
                _a,
                capacitor,
                _b.chainSlug,
                _transmitterPrivateKey
            );
        _sealOnSrc(_a, capacitor, DEFAULT_BATCH_LENGTH, sig_);

        uint256 proposalCount = 0;
        vm.expectEmit(false, false, false, true);
        emit PacketProposed(
            _transmitter,
            packetId_,
            proposalCount,
            root_,
            address(_b.configs__[0].switchboard__)
        );
        _proposeOnDst(
            _b,
            sig_,
            packetId_,
            root_,
            address(_b.configs__[0].switchboard__)
        );

        assertEq(
            _b.socket__.packetIdRoots(
                packetId_,
                proposalCount,
                address(_b.configs__[0].switchboard__)
            ),
            root_
        );
        assertEq(
            _b.socket__.rootProposedAt(
                packetId_,
                proposalCount,
                address(_b.configs__[0].switchboard__)
            ),
            block.timestamp
        );
    }

    function testInvalidPacketPropose() external {
        uint32 msgIdSrcSlug = uint32(uint256(0x12345));
        uint32 packetIdSrcSlug = uint32(uint256(0x12346));
        uint32 dstSlug = _b.chainSlug;

        uint64 packetCount = 0;
        bytes32 root = bytes32("ROOT");

        bytes32 msgId = _packMessageId(msgIdSrcSlug, address(dstCounter__), 0);

        address capacitor = address(uint160(c++));
        uint256 executionFee = 10000;
        bytes memory payload = abi.encode(keccak256("OP_ADD"), 100, _plugOwner);

        bytes32 packetId = _getPackedId(
            capacitor,
            packetIdSrcSlug,
            packetCount
        );
        bytes32 digest = keccak256(
            abi.encode(versionHash, dstSlug, packetId, root)
        );
        bytes memory sig = _createSignature(digest, _transmitterPrivateKey);

        hoax(_socketOwner);
        _b.transmitManager__.grantRoleWithSlug(
            TRANSMITTER_ROLE,
            packetIdSrcSlug,
            vm.addr(_transmitterPrivateKey)
        );

        _proposeOnDst(
            _b,
            sig,
            packetId,
            root,
            address(_b.configs__[0].switchboard__)
        );

        hoax(_socketOwner);
        FastSwitchboard(address(_b.configs__[index].switchboard__))
            .grantWatcherRole(packetIdSrcSlug, _watcher);

        uint256 proposalCount;
        _attestOnDst(
            address(_b.configs__[index].switchboard__),
            _b.chainSlug,
            packetId,
            proposalCount,
            root,
            _watcherPrivateKey
        );

        vm.expectRevert(SocketDst.ErrInSourceValidation.selector);
        _executePayloadOnDst(
            _b,
            ExecutePayloadOnDstParams(
                packetId,
                proposalCount,
                msgId,
                _minMsgGasLimit,
                bytes32(0),
                executionFee,
                root,
                payload,
                abi.encode(0)
            )
        );
    }

    function testIsPacketProposed() external {
        address capacitor = address(_a.configs__[index].capacitor__);
        sendOutboundMessage();

        (
            bytes32 root_,
            bytes32 packetId_,
            bytes memory sig_
        ) = getLatestSignature(
                _a,
                capacitor,
                _b.chainSlug,
                _transmitterPrivateKey
            );

        _sealOnSrc(_a, capacitor, DEFAULT_BATCH_LENGTH, sig_);
        uint256 proposalCount;
        assertFalse(
            _b.socket__.isPacketProposed(
                packetId_,
                proposalCount,
                address(_b.configs__[0].switchboard__)
            )
        );
        _proposeOnDst(
            _b,
            sig_,
            packetId_,
            root_,
            address(_b.configs__[0].switchboard__)
        );

        assertEq(
            _b.socket__.packetIdRoots(
                packetId_,
                proposalCount,
                address(_b.configs__[0].switchboard__)
            ),
            root_
        );
        assertTrue(
            _b.socket__.isPacketProposed(
                packetId_,
                proposalCount,
                address(_b.configs__[0].switchboard__)
            )
        );
    }

    function testProposeAPacketByInvalidTransmitter() external {
        address capacitor = address(_a.configs__[index].capacitor__);

        sendOutboundMessage();

        (
            bytes32 root_,
            bytes32 packetId_,
            bytes memory sig_
        ) = getLatestSignature(
                _a,
                capacitor,
                _b.chainSlug,
                _altTransmitterPrivateKey
            );

        vm.expectRevert(InvalidTransmitter.selector);

        _proposeOnDst(
            _b,
            sig_,
            packetId_,
            root_,
            address(_b.configs__[0].switchboard__)
        );
    }

    function testProposeWithInvalidChainSlug() external {
        uint32 randomChainSlug = cChainSlug;
        bytes32 packetId = _getPackedId(
            address(uint160(c++)),
            randomChainSlug,
            100
        );
        bytes32 root = bytes32("RANDOM_ROOT");

        bytes32 digest = keccak256(
            abi.encode(versionHash, randomChainSlug, packetId, root)
        );

        bytes memory sig = _createSignature(digest, _transmitterPrivateKey);

        vm.expectRevert(InvalidTransmitter.selector);
        _b.socket__.proposeForSwitchboard(
            packetId,
            root,
            address(_b.configs__[0].switchboard__),
            sig
        );
    }

    function testDuplicateProposePacket() external {
        address capacitor = address(_a.configs__[index].capacitor__);

        sendOutboundMessage();
        (, , bytes memory sig_) = getLatestSignature(
            _a,
            capacitor,
            _b.chainSlug,
            _transmitterPrivateKey
        );
        (bytes32 packetId_, bytes32 root_) = sealAndPropose(
            capacitor,
            DEFAULT_BATCH_LENGTH
        );
        assertEq(
            _b.socket__.packetIdRoots(
                packetId_,
                0,
                address(_b.configs__[0].switchboard__)
            ),
            root_
        );
        // vm.expectRevert(AlreadyProposed.selector);
        _proposeOnDst(
            _b,
            sig_,
            packetId_,
            root_,
            address(_b.configs__[0].switchboard__)
        );
        assertEq(
            _b.socket__.packetIdRoots(
                packetId_,
                1,
                address(_b.configs__[0].switchboard__)
            ),
            root_
        );

        assertEq(_b.socket__.proposalCount(packetId_), 2);
    }

    function sendOutboundMessage() internal {
        uint256 amount = 100;

        uint256 minFees = _a.socket__.getMinFees(
            _minMsgGasLimit,
            1000,
            bytes32(0),
            _transmissionParams,
            _b.chainSlug,
            address(srcCounter__)
        );

        hoax(_plugOwner);
        srcCounter__.remoteAddOperation{value: minFees}(
            _b.chainSlug,
            amount,
            _minMsgGasLimit,
            bytes32(0),
            bytes32(0)
        );
    }

    function testExecuteMessageOnSocketDst() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(
            keccak256("OP_ADD"),
            amount,
            _plugOwner
        );
        bytes memory proof = abi.encode(0);
        address capacitor = address(_a.configs__[index].capacitor__);

        uint256 executionFee;
        {
            (uint256 switchboardFees, uint256 verificationFee) = _a
                .configs__[index]
                .switchboard__
                .getMinFees(_b.chainSlug);

            uint256 socketFees;
            (executionFee, socketFees) = _a
                .executionManager__
                .getExecutionTransmissionMinFees(
                    _minMsgGasLimit,
                    100,
                    bytes32(0),
                    _transmissionParams,
                    _b.chainSlug,
                    address(_a.transmitManager__)
                );

            uint256 value = switchboardFees +
                socketFees +
                verificationFee +
                executionFee;

            // executionFees to be recomputed which is totalValue - (socketFees + switchboardFees)
            // verificationOverheadFees also should go to Executor, hence we do the additional computation below
            executionFee = verificationFee + executionFee;

            hoax(_plugOwner);
            srcCounter__.remoteAddOperation{value: value}(
                _b.chainSlug,
                amount,
                _minMsgGasLimit,
                bytes32(0),
                bytes32(0)
            );
        }

        bytes32 msgId = _packMessageId(_a.chainSlug, address(dstCounter__), 0);
        (bytes32 packetId, bytes32 root) = sealAndPropose(
            capacitor,
            DEFAULT_BATCH_LENGTH
        );
        _attestOnDst(
            address(_b.configs__[index].switchboard__),
            _b.chainSlug,
            packetId,
            0,
            root,
            _watcherPrivateKey
        );

        vm.expectEmit(true, false, false, false);
        emit ExecutionSuccess(msgId);

        _executePayloadOnDst(
            _b,
            ExecutePayloadOnDstParams(
                packetId,
                0,
                msgId,
                _minMsgGasLimit,
                bytes32(0),
                executionFee,
                root,
                payload,
                proof
            )
        );

        assertEq(dstCounter__.counter(), amount);
        assertEq(srcCounter__.counter(), 0);
        assertTrue(_b.socket__.messageExecuted(msgId));

        vm.expectRevert(SocketDst.MessageAlreadyExecuted.selector);
        _executePayloadOnDst(
            _b,
            ExecutePayloadOnDstParams(
                packetId,
                0,
                msgId,
                _minMsgGasLimit,
                bytes32(0),
                executionFee,
                root,
                payload,
                proof
            )
        );
    }

    function testExecuteMessageWithValue() external {
        uint256 amount = 100;
        uint256 msgValue = 100;
        uint paramType = 1;
        bytes32 executionParams = bytes32(
            uint256((uint256(paramType) << 224) | uint224(msgValue))
        );

        bytes memory payload = abi.encode(
            keccak256("OP_ADD"),
            amount,
            _plugOwner
        );
        bytes memory proof = abi.encode(0);
        address capacitor = address(_a.configs__[index].capacitor__);

        uint256 executionFee;
        {
            (uint256 switchboardFees, uint256 verificationFee) = _a
                .configs__[index]
                .switchboard__
                .getMinFees(_b.chainSlug);

            uint256 socketFees;
            (executionFee, socketFees) = _a
                .executionManager__
                .getExecutionTransmissionMinFees(
                    _minMsgGasLimit,
                    100,
                    bytes32(0),
                    _transmissionParams,
                    _b.chainSlug,
                    address(_a.transmitManager__)
                );

            uint256 value = switchboardFees +
                socketFees +
                verificationFee +
                executionFee;

            // executionFees to be recomputed which is totalValue - (socketFees + switchboardFees)
            // verificationOverheadFees also should go to Executor, hence we do the additional computation below
            executionFee = verificationFee + executionFee;

            hoax(_plugOwner);
            srcCounter__.remoteAddOperation{value: value}(
                _b.chainSlug,
                amount,
                _minMsgGasLimit,
                executionParams,
                bytes32(0)
            );
        }

        bytes32 msgId = _packMessageId(_a.chainSlug, address(dstCounter__), 0);
        (bytes32 packetId, bytes32 root) = sealAndPropose(
            capacitor,
            DEFAULT_BATCH_LENGTH
        );
        uint256 proposalCount;
        _attestOnDst(
            address(_b.configs__[index].switchboard__),
            _b.chainSlug,
            packetId,
            proposalCount,
            root,
            _watcherPrivateKey
        );

        _executePayloadOnDst(
            _b,
            ExecutePayloadOnDstParams(
                packetId,
                proposalCount,
                msgId,
                _minMsgGasLimit,
                executionParams,
                executionFee,
                root,
                payload,
                proof
            )
        );
    }

    function testExecuteMessageWithInvalidExecutor() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(
            keccak256("OP_ADD"),
            amount,
            _plugOwner
        );
        bytes memory proof = abi.encode(0);
        address capacitor = address(_a.configs__[index].capacitor__);

        uint256 executionFee;
        {
            (uint256 switchboardFees, uint256 verificationFee) = _a
                .configs__[index]
                .switchboard__
                .getMinFees(_b.chainSlug);

            uint256 socketFees;
            (executionFee, socketFees) = _a
                .executionManager__
                .getExecutionTransmissionMinFees(
                    _minMsgGasLimit,
                    100,
                    bytes32(0),
                    _transmissionParams,
                    _b.chainSlug,
                    address(_a.transmitManager__)
                );

            uint256 value = switchboardFees +
                socketFees +
                verificationFee +
                executionFee;

            // executionFees to be recomputed which is totalValue - (socketFees + switchboardFees)
            // verificationOverheadFees also should go to Executor, hence we do the additional computation below
            executionFee = verificationFee + executionFee;

            hoax(_plugOwner);
            srcCounter__.remoteAddOperation{value: value}(
                _b.chainSlug,
                amount,
                _minMsgGasLimit,
                bytes32(0),
                bytes32(0)
            );
        }

        bytes32 msgId = _packMessageId(_a.chainSlug, address(dstCounter__), 0);
        (bytes32 packetId, bytes32 root) = sealAndPropose(
            capacitor,
            DEFAULT_BATCH_LENGTH
        );
        uint256 proposalCount;
        _attestOnDst(
            address(_b.configs__[index].switchboard__),
            _b.chainSlug,
            packetId,
            proposalCount,
            root,
            _watcherPrivateKey
        );

        vm.expectRevert(NotExecutor.selector);
        _executePayloadOnDstWithExecutor(
            _b,
            uint256(1),
            ExecutePayloadOnDstParams(
                packetId,
                proposalCount,
                msgId,
                _minMsgGasLimit,
                bytes32(0),
                executionFee,
                root,
                payload,
                proof
            )
        );
    }

    function testExecuteVerification() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(
            keccak256("OP_ADD"),
            amount,
            _plugOwner
        );
        bytes memory proof = abi.encode(0);
        address capacitor = address(_a.configs__[index].capacitor__);

        uint256 executionFee;
        {
            (uint256 switchboardFees, uint256 verificationFee) = _a
                .configs__[index]
                .switchboard__
                .getMinFees(_b.chainSlug);

            uint256 socketFees;
            (executionFee, socketFees) = _a
                .executionManager__
                .getExecutionTransmissionMinFees(
                    _minMsgGasLimit,
                    100,
                    bytes32(0),
                    _transmissionParams,
                    _b.chainSlug,
                    address(_a.transmitManager__)
                );

            uint256 value = switchboardFees +
                socketFees +
                verificationFee +
                executionFee;

            // executionFees to be recomputed which is totalValue - (socketFees + switchboardFees)
            // verificationOverheadFees also should go to Executor, hence we do the additional computation below
            executionFee = verificationFee + executionFee;

            hoax(_plugOwner);
            srcCounter__.remoteAddOperation{value: value}(
                _b.chainSlug,
                amount,
                _minMsgGasLimit,
                bytes32(0),
                bytes32(0)
            );
        }

        bytes32 msgId = _packMessageId(_a.chainSlug, address(dstCounter__), 0);
        (
            bytes32 root,
            bytes32 packetId,
            bytes memory sig_
        ) = _getLatestSignature(capacitor, _a.chainSlug, _b.chainSlug);

        _sealOnSrc(_a, capacitor, DEFAULT_BATCH_LENGTH, sig_);
        uint256 proposalCount;

        // low gas limit
        uint256 executionGasLimit = 0;
        vm.expectRevert(SocketDst.LowGasLimit.selector);
        _executePayloadOnDstWithDiffLimit(
            executionGasLimit,
            _b,
            ExecutePayloadOnDstParams(
                packetId,
                proposalCount,
                msgId,
                _minMsgGasLimit,
                bytes32(0),
                executionFee,
                root,
                payload,
                proof
            )
        );

        // invalid packet id
        vm.expectRevert(SocketDst.InvalidPacketId.selector);
        _executePayloadOnDst(
            _b,
            ExecutePayloadOnDstParams(
                bytes32(0),
                proposalCount,
                msgId,
                _minMsgGasLimit,
                bytes32(0),
                executionFee,
                root,
                payload,
                proof
            )
        );

        // not proposed
        vm.expectRevert(SocketDst.PacketNotProposed.selector);
        _executePayloadOnDst(
            _b,
            ExecutePayloadOnDstParams(
                packetId,
                proposalCount,
                msgId,
                _minMsgGasLimit,
                bytes32(0),
                executionFee,
                root,
                payload,
                proof
            )
        );

        // not attested
        _proposeOnDst(
            _b,
            sig_,
            packetId,
            root,
            address(_b.configs__[0].switchboard__)
        );
        vm.expectRevert(SocketDst.VerificationFailed.selector);
        _executePayloadOnDst(
            _b,
            ExecutePayloadOnDstParams(
                packetId,
                proposalCount,
                msgId,
                _minMsgGasLimit,
                bytes32(0),
                executionFee,
                root,
                payload,
                proof
            )
        );

        // invalid proof
        _attestOnDst(
            address(_b.configs__[index].switchboard__),
            _b.chainSlug,
            packetId,
            proposalCount,
            root,
            _watcherPrivateKey
        );

        ISocket.MessageDetails memory msgDetails = ISocket.MessageDetails(
            msgId,
            executionFee,
            _minMsgGasLimit + 100,
            bytes32(0),
            payload
        );

        bytes memory sig = _createSignature(
            _b.hasher__.packMessage(
                _a.chainSlug,
                address(srcCounter__),
                _b.chainSlug,
                address(dstCounter__),
                msgDetails
            ),
            _executorPrivateKey
        );

        ISocket.ExecutionDetails memory executionDetails = ISocket
            .ExecutionDetails(
                packetId,
                proposalCount,
                _minMsgGasLimit + 100,
                proof,
                sig
            );

        vm.expectRevert(SocketDst.InvalidProof.selector);
        _b.socket__.execute(executionDetails, msgDetails);
    }

    function getLatestSignature(
        ChainContext memory src_,
        address capacitor_,
        uint32 remoteChainSlug_,
        uint256 transmitterPrivateKey_
    ) public view returns (bytes32 root, bytes32 packetId, bytes memory sig) {
        uint256 id;
        (root, id) = ICapacitor(capacitor_).getNextPacketToBeSealed();
        packetId = _getPackedId(capacitor_, src_.chainSlug, id);
        bytes32 digest = keccak256(
            abi.encode(versionHash, remoteChainSlug_, packetId, root)
        );

        sig = _createSignature(digest, transmitterPrivateKey_);
    }

    function _deployPlugContracts() internal {
        vm.startPrank(_plugOwner);

        // deploy counters
        srcCounter__ = new Counter(address(_a.socket__));
        dstCounter__ = new Counter(address(_b.socket__));

        vm.stopPrank();
    }

    function _configPlugContracts(uint256 socketConfigIndex) internal {
        hoax(_plugOwner);
        srcCounter__.setSocketConfig(
            _b.chainSlug,
            address(dstCounter__),
            address(_a.configs__[socketConfigIndex].switchboard__)
        );

        hoax(_plugOwner);
        dstCounter__.setSocketConfig(
            _a.chainSlug,
            address(srcCounter__),
            address(_b.configs__[socketConfigIndex].switchboard__)
        );
    }
}

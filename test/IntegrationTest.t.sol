// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "./Setup.t.sol";
import "../contracts/examples/Counter.sol";

contract HappyTest is Setup {
    Counter srcCounter__;
    Counter dstCounter__;

    uint256 addAmount = 100;
    uint256 subAmount = 40;
    bool isFast = true;
    uint256 index = isFast ? 0 : 1;

    bytes32[] roots;

    event ExecutionSuccess(bytes32 msgId);
    event ExecutionFailed(bytes32 msgId, string result);
    event ExecutionFailedBytes(bytes32 msgId, bytes result);
    event PacketVerifiedAndSealed(
        address indexed transmitter,
        bytes32 indexed packetId,
        bytes32 root,
        bytes signature
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

    function testRemoteAddFromAtoB() external {
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

        bytes32 packetId;
        bytes32 root;
        {
            bytes memory sig_;
            (root, packetId, sig_) = _getLatestSignature(
                capacitor,
                _a.chainSlug,
                _b.chainSlug
            );

            _sealOnSrc(_a, capacitor, DEFAULT_BATCH_LENGTH, sig_);
            _proposeOnDst(
                _b,
                sig_,
                packetId,
                root,
                address(_b.configs__[0].switchboard__)
            );
            uint256 proposalCount;
            _attestOnDst(
                address(_b.configs__[0].switchboard__),
                _b.chainSlug,
                packetId,
                proposalCount,
                root,
                _watcherPrivateKey
            );
        }

        vm.expectEmit(true, false, false, false);
        emit ExecutionSuccess(
            _packMessageId(_a.chainSlug, address(dstCounter__), 0)
        );
        _executePayloadOnDst(
            _b,
            ExecutePayloadOnDstParams(
                packetId,
                0,
                _packMessageId(_a.chainSlug, address(dstCounter__), 0),
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
        assertTrue(
            _b.socket__.messageExecuted(
                _packMessageId(_a.chainSlug, address(dstCounter__), 0)
            )
        );

        vm.expectRevert(SocketDst.MessageAlreadyExecuted.selector);
        _executePayloadOnDst(
            _b,
            ExecutePayloadOnDstParams(
                packetId,
                0,
                _packMessageId(_a.chainSlug, address(dstCounter__), 0),
                _minMsgGasLimit,
                bytes32(0),
                executionFee,
                root,
                payload,
                proof
            )
        );

        // with different proposal id
        vm.expectRevert(SocketDst.MessageAlreadyExecuted.selector);
        _executePayloadOnDst(
            _b,
            ExecutePayloadOnDstParams(
                packetId,
                1,
                _packMessageId(_a.chainSlug, address(dstCounter__), 0),
                _minMsgGasLimit,
                bytes32(0),
                executionFee,
                root,
                payload,
                proof
            )
        );
    }

    // function testRemoteAddFromBtoA() external {
    //     uint256 amount = 100;
    //     bytes memory payload = abi.encode(
    //         keccak256("OP_ADD"),
    //         amount,
    //         _plugOwner
    //     );
    //     bytes memory proof = abi.encode(0);
    //     address capacitor = isFast
    //         ? address(_b.configs__[0].capacitor__)
    //         : address(_b.configs__[1].capacitor__);

    //     sendOutboundMessage(_b, _a.chainSlug);
    //     (
    //         bytes32 root,
    //         bytes32 packetId,
    //         bytes memory sig
    //     ) = _getLatestSignature(capacitor, _b.chainSlug, _a.chainSlug);

    //     _sealOnSrc(_b, capacitor, DEFAULT_BATCH_LENGTH, sig);
    //     _proposeOnDst(
    //         _a,
    //         sig,
    //         packetId,
    //         root,
    //         address(_a.configs__[0].switchboard__)
    //     );
    //     _attestOnDst(
    //         address(_a.configs__[0].switchboard__),
    //         _a.chainSlug,
    //         packetId,
    //         0,
    //         root,
    //         _watcherPrivateKey
    //     );

    //     _executePayloadOnDst(
    //         _a,
    //         ExecutePayloadOnDstParams(
    //             packetId,
    //             0,
    //             _packMessageId(_b.chainSlug, address(srcCounter__), 0),
    //             _minMsgGasLimit,
    //             bytes32(0),
    //             _executionFees,
    //             root,
    //             payload,
    //             proof
    //         )
    //     );

    //     assertEq(srcCounter__.counter(), amount);
    //     assertEq(dstCounter__.counter(), 0);
    // }

    function outbound(
        uint256 count,
        uint256 amount,
        uint256 executionFees,
        uint256 fees,
        bytes memory payload
    ) internal returns (bytes32 msgId, bytes32 root) {
        uint256 minMsgGasLimit = _minMsgGasLimit;
        uint32 dstSlug = _b.chainSlug;

        hoax(_plugOwner);
        srcCounter__.remoteAddOperation{value: fees}(
            dstSlug,
            amount,
            _minMsgGasLimit,
            bytes32(0),
            bytes32(0)
        );

        msgId = _packMessageId(_a.chainSlug, address(dstCounter__), count);
        ISocket.MessageDetails memory messageDetails;
        messageDetails.msgId = msgId;
        messageDetails.minMsgGasLimit = minMsgGasLimit;
        messageDetails.executionFee = executionFees;
        messageDetails.payload = payload;

        root = _a.hasher__.packMessage(
            _a.chainSlug,
            address(srcCounter__),
            dstSlug,
            address(dstCounter__),
            messageDetails
        );
    }

    // function testRemoteAddFromAtoBHashCapacitor() external {
    //     SocketConfigContext memory srcConfig = _addFastSwitchboard(
    //         _a,
    //         _b.chainSlug,
    //         2
    //     );
    //     SocketConfigContext memory dstConfig = _addFastSwitchboard(
    //         _b,
    //         _a.chainSlug,
    //         2
    //     );

    //     _a.configs__.push(srcConfig);
    //     _b.configs__.push(dstConfig);

    //     _configPlugContracts(_a.configs__.length - 1);

    //     uint256 amount = 100;
    //     bytes memory payload = abi.encode(
    //         keccak256("OP_ADD"),
    //         amount,
    //         _plugOwner
    //     );

    //     uint256 executionFee;
    //     bytes32 msgId1;
    //     bytes32 root1;
    //     bytes32 msgId2;
    //     bytes32 root2;
    //     {
    //         (uint256 switchboardFees, uint256 executionOverhead) = srcConfig
    //             .switchboard__
    //             .getMinFees(_b.chainSlug);

    //         uint256 socketFees = _a.transmitManager__.getMinFees(_b.chainSlug);
    //         executionFee = _a.executionManager__.getMinFees(
    //             _minMsgGasLimit,
    //             100,
    //             bytes32(0),
    // _transmissionParams,

    //             _b.chainSlug
    //         );

    //         uint256 fees = switchboardFees +
    //             executionOverhead +
    //             socketFees +
    //             executionFee;

    //         // executionFees to be recomputed which is totalValue - (socketFees + switchboardFees)
    //         // verificationOverheadFees also should go to Executor, hence we do the additional computation below
    //         executionFee = executionOverhead + executionFee;

    //         // send 2 messages
    //         (msgId1, root1) = outbound(0, amount, executionFee, fees, payload);
    //         (msgId2, root2) = outbound(1, amount, executionFee, fees, payload);
    //     }

    // seal 2 messages together
    // (bytes32 packetId, ) = sealAndPropose(
    //     address(srcConfig.capacitor__),
    //     2
    // );
    // roots.push(root1);
    // roots.push(root2);

    //     uint256 proposalCount;
    //     _attestOnDst(
    //         address(_b.configs__[_b.configs__.length - 1].switchboard__),
    //         _b.chainSlug,
    //         packetId,
    //         proposalCount,
    //         _watcherPrivateKey
    //     );

    //     // execute msg 1
    //     vm.expectEmit(true, false, false, false);
    //     emit ExecutionSuccess(msgId1);

    // _executePayloadOnDst(
    //     _b,
    //     ExecutePayloadOnDstParams(
    //         packetId,
    //         0,
    //         msgId1,
    //         _minMsgGasLimit,
    //         bytes32(0),
    //         executionFee,
    //         root1,
    //         payload,
    //         abi.encode(roots)
    //     )
    // );

    //     assertEq(dstCounter__.counter(), amount);
    //     assertEq(srcCounter__.counter(), 0);

    //     // execute msg 2
    //     vm.expectEmit(true, false, false, false);
    //     emit ExecutionSuccess(msgId2);

    // _executePayloadOnDst(
    //     _b,
    //     ExecutePayloadOnDstParams(
    //         packetId,
    //         0,
    //         msgId2,
    //         _minMsgGasLimit,
    //         bytes32(0),
    //         executionFee,
    //         root2,
    //         payload,
    //         abi.encode(roots)
    //     )
    // );

    //     assertEq(dstCounter__.counter(), 2 * amount);
    //     assertEq(srcCounter__.counter(), 0);
    // }

    function testRescueFunds() public {
        uint256 amount = 1e18;

        hoax(_socketOwner);
        _rescueNative(
            address(_a.hasher__),
            NATIVE_TOKEN_ADDRESS,
            _fundRescuer,
            amount
        );

        hoax(_socketOwner);
        _rescueNative(
            address(_a.sigVerifier__),
            NATIVE_TOKEN_ADDRESS,
            _fundRescuer,
            amount
        );
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

    function sendOutboundMessage(
        ChainContext storage cc_,
        uint32 siblingChainSlug_
    ) internal {
        uint256 amount = 100;

        uint256 minFees = cc_.socket__.getMinFees(
            _minMsgGasLimit,
            1000,
            bytes32(0),
            _transmissionParams,
            siblingChainSlug_,
            address(srcCounter__)
        );

        hoax(_plugOwner);
        srcCounter__.remoteAddOperation{value: minFees}(
            siblingChainSlug_,
            amount,
            _minMsgGasLimit,
            bytes32(0),
            bytes32(0)
        );
    }
}

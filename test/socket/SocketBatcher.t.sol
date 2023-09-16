// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../Setup.t.sol";
import "../../contracts/socket/SocketBatcher.sol";
import "../../contracts/examples/Counter.sol";

contract SocketBatcherTest is Setup {
    Counter srcCounter__;
    Counter dstCounter__;
    SocketBatcher batcher__;

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
        batcher__ = new SocketBatcher(address(this));
    }

    function testSendBatch() external {
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

            SocketBatcher.ProposeRequest memory proposeRequest = SocketBatcher
                .ProposeRequest({
                    packetId: packetId,
                    root: root,
                    switchboard: address(_b.configs__[0].switchboard__),
                    signature: sig_
                });
            SocketBatcher.ProposeRequest[]
                memory proposeRequests = new SocketBatcher.ProposeRequest[](1);
            proposeRequests[0] = proposeRequest;

            bytes32 digest = keccak256(
                abi.encode(
                    address(_b.configs__[0].switchboard__),
                    _b.chainSlug,
                    packetId,
                    0,
                    root
                )
            );

            // generate attest-signature
            bytes memory attestSignature = _createSignature(
                digest,
                _watcherPrivateKey
            );

            SocketBatcher.AttestRequest memory attestRequest = SocketBatcher
                .AttestRequest({
                    packetId: packetId,
                    proposalCount: 0,
                    root: root,
                    signature: attestSignature
                });

            SocketBatcher.AttestRequest[]
                memory attestRequests = new SocketBatcher.AttestRequest[](1);
            attestRequests[0] = attestRequest;
            SocketBatcher.ExecuteRequest[] memory executeRequests;

            batcher__.sendBatch(
                address(_b.socket__),
                address(_b.configs__[0].switchboard__),
                proposeRequests,
                attestRequests,
                executeRequests
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

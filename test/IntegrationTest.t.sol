// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Setup.t.sol";
import "../contracts/examples/Counter.sol";

contract HappyTest is Setup {
    Counter srcCounter__;
    Counter dstCounter__;

    uint256 addAmount = 100;
    uint256 subAmount = 40;
    uint256 sourceGasPrice = 1200000;
    uint256 relativeGasPrice = 1100000;

    bool isFast = true;
    bytes32[] roots;
    uint256 index = isFast ? 0 : 1;

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
        uint256[] memory transmitterPivateKeys = new uint256[](1);
        transmitterPivateKeys[0] = _transmitterPrivateKey;

        _dualChainSetup(transmitterPivateKeys);
        _deployPlugContracts();

        _configPlugContracts(index);

        vm.startPrank(_transmitter);
        _a.gasPriceOracle__.setSourceGasPrice(sourceGasPrice);
        _a.gasPriceOracle__.setRelativeGasPrice(_b.chainSlug, relativeGasPrice);
        vm.stopPrank();
    }

    function testRemoteAddFromAtoB1() external {
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

            uint256 socketFees = _a.transmitManager__.getMinFees(_b.chainSlug);
            executionFee = _a.executionManager__.getMinFees(
                _msgGasLimit,
                _b.chainSlug
            );

            uint256 value = switchboardFees +
                socketFees +
                verificationFee +
                executionFee;

            // executionFees to be recomputed which is totalValue - (socketFees + switchBoardFees)
            // verificationFees also should go to Executor, hence we do the additional computation below
            executionFee = verificationFee + executionFee;

            hoax(_plugOwner);
            srcCounter__.remoteAddOperation{value: value}(
                _b.chainSlug,
                amount,
                _msgGasLimit
            );
        }

        // uint256 msgId = _packMessageId(_a.chainSlug, 0);
        bytes32 packetId;
        bytes32 root;
        {
            (
                bytes32 root_,
                bytes32 packetId_,
                bytes memory sig_
            ) = _getLatestSignature(_a, capacitor, _b.chainSlug);

            _sealOnSrc(_a, capacitor, sig_);
            _proposeOnDst(_b, sig_, packetId_, root_);
            root = root_;
            _attestOnDst(address(_b.configs__[0].switchboard__), packetId_);
            packetId = packetId_;
        }

        vm.expectEmit(true, false, false, false);
        emit ExecutionSuccess(_packMessageId(_a.chainSlug, 0));
        _executePayloadOnDst(
            _b,
            _a.chainSlug,
            address(dstCounter__),
            packetId,
            _packMessageId(_a.chainSlug, 0),
            _msgGasLimit,
            executionFee,
            root,
            payload,
            proof
        );

        assertEq(dstCounter__.counter(), amount);
        assertEq(srcCounter__.counter(), 0);
        assertTrue(
            _b.socket__.messageExecuted(_packMessageId(_a.chainSlug, 0))
        );

        vm.expectRevert(SocketDst.MessageAlreadyExecuted.selector);
        _executePayloadOnDst(
            _b,
            _a.chainSlug,
            address(dstCounter__),
            packetId,
            _packMessageId(_a.chainSlug, 0),
            _msgGasLimit,
            executionFee,
            root,
            payload,
            proof
        );
    }

    function testRemoteAddFromBtoA() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(
            keccak256("OP_ADD"),
            amount,
            _plugOwner
        );
        bytes memory proof = abi.encode(0);
        address capacitor = isFast
            ? address(_b.configs__[0].capacitor__)
            : address(_b.configs__[1].capacitor__);

        uint256 minFees = _b.transmitManager__.getMinFees(_a.chainSlug);

        hoax(_plugOwner);
        dstCounter__.remoteAddOperation{value: minFees}(
            _a.chainSlug,
            amount,
            _msgGasLimit
        );

        (
            bytes32 root,
            bytes32 packetId,
            bytes memory sig
        ) = _getLatestSignature(_b, capacitor, _a.chainSlug);

        _sealOnSrc(_b, capacitor, sig);
        _proposeOnDst(_a, sig, packetId, root);
        _attestOnDst(address(_a.configs__[0].switchboard__), packetId);

        _executePayloadOnDst(
            _a,
            _b.chainSlug,
            address(srcCounter__),
            packetId,
            _packMessageId(_b.chainSlug, 0),
            _msgGasLimit,
            0,
            root,
            payload,
            proof
        );

        assertEq(srcCounter__.counter(), amount);
        assertEq(dstCounter__.counter(), 0);
    }

    function outbound(
        uint256 count,
        uint256 amount,
        uint256 executionFees,
        uint256 fees,
        bytes memory payload
    ) internal returns (bytes32 msgId, bytes32 root) {
        uint256 msgGasLimit = _msgGasLimit;
        uint256 dstSlug = _b.chainSlug;

        hoax(_plugOwner);
        srcCounter__.remoteAddOperation{value: fees}(
            dstSlug,
            amount,
            msgGasLimit
        );

        msgId = _packMessageId(_a.chainSlug, count);
        root = _a.hasher__.packMessage(
            _a.chainSlug,
            address(srcCounter__),
            dstSlug,
            address(dstCounter__),
            msgId,
            msgGasLimit,
            executionFees,
            payload
        );
    }

    function sealAndPropose(address capacitor) internal returns (bytes32) {
        (
            bytes32 root_,
            bytes32 packetId_,
            bytes memory sig_
        ) = _getLatestSignature(_a, capacitor, _b.chainSlug);

        vm.expectEmit(false, false, false, true);
        emit PacketVerifiedAndSealed(_transmitter, packetId_, root_, sig_);
        _sealOnSrc(_a, capacitor, sig_);
        _proposeOnDst(_b, sig_, packetId_, root_);

        return packetId_;
    }

    function testRemoteAddFromAtoBHashCapacitor() external {
        SocketConfigContext memory srcConfig = _addFastSwitchboard(
            _a,
            _b.chainSlug,
            2
        );
        SocketConfigContext memory dstConfig = _addFastSwitchboard(
            _b,
            _a.chainSlug,
            2
        );

        _a.configs__.push(srcConfig);
        _b.configs__.push(dstConfig);

        _configPlugContracts(_a.configs__.length - 1);

        uint256 amount = 100;
        bytes memory payload = abi.encode(
            keccak256("OP_ADD"),
            amount,
            _plugOwner
        );

        uint256 executionFee;
        bytes32 msgId1;
        bytes32 root1;
        bytes32 msgId2;
        bytes32 root2;
        {
            (uint256 switchboardFees, uint256 executionOverhead) = srcConfig
                .switchboard__
                .getMinFees(_b.chainSlug);

            uint256 socketFees = _a.transmitManager__.getMinFees(_b.chainSlug);
            executionFee = _a.executionManager__.getMinFees(
                _msgGasLimit,
                _b.chainSlug
            );

            uint256 fees = switchboardFees +
                executionOverhead +
                socketFees +
                executionFee;

            // executionFees to be recomputed which is totalValue - (socketFees + switchBoardFees)
            // verificationFees also should go to Executor, hence we do the additional computation below
            executionFee = executionOverhead + executionFee;

            // send 2 messages
            (msgId1, root1) = outbound(0, amount, executionFee, fees, payload);
            (msgId2, root2) = outbound(1, amount, executionFee, fees, payload);
        }

        // seal 2 messages together
        bytes32 packetId = sealAndPropose(address(srcConfig.capacitor__));
        roots.push(root1);
        roots.push(root2);

        _attestOnDst(
            address(_b.configs__[_b.configs__.length - 1].switchboard__),
            packetId
        );

        // execute msg 1
        vm.expectEmit(true, false, false, false);
        emit ExecutionSuccess(msgId1);

        _executePayloadOnDst(
            _b,
            _a.chainSlug,
            address(dstCounter__),
            packetId,
            msgId1,
            _msgGasLimit,
            executionFee,
            root1,
            payload,
            abi.encode(roots)
        );

        assertEq(dstCounter__.counter(), amount);
        assertEq(srcCounter__.counter(), 0);

        // execute msg 2
        vm.expectEmit(true, false, false, false);
        emit ExecutionSuccess(msgId2);

        _executePayloadOnDst(
            _b,
            _a.chainSlug,
            address(dstCounter__),
            packetId,
            msgId2,
            _msgGasLimit,
            executionFee,
            root2,
            payload,
            abi.encode(roots)
        );

        assertEq(dstCounter__.counter(), 2 * amount);
        assertEq(srcCounter__.counter(), 0);
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

    function _attesterChecks(
        address capacitor
    ) internal returns (bytes32 packetId, bytes32 root) {
        bytes memory sig;
        (root, packetId, sig) = _getLatestSignature(
            _a,
            capacitor,
            _b.chainSlug
        );
        _sealOnSrc(_a, capacitor, sig);
        _proposeOnDst(_b, sig, packetId, root);
    }
}

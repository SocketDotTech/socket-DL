// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../Setup.t.sol";
import "../../contracts/examples/Counter.sol";

contract SocketDstTest is Setup {
    Counter srcCounter__;
    Counter dstCounter__;

    uint256 addAmount = 100;
    uint256 subAmount = 40;

    uint256 sealGasLimit = 200000;
    uint256 proposeGasLimit = 100000;
    uint256 sourceGasPrice = 1200000;
    uint256 relativeGasPrice = 1100000;
    address immutable _invalidExecutor = address(uint160(c++));

    bool isFast = true;
    uint256 index = isFast ? 0 : 1;

    bytes32[] roots;

    error AlreadyAttested();
    error InvalidAttester();
    error InsufficientFees();
    error InvalidProof();
    error NotExecutor();
    event ExecutionSuccess(bytes32 msgId);
    event ExecutionFailed(bytes32 msgId, string result);
    event ExecutionFailedBytes(bytes32 msgId, bytes result);

    event PacketVerifiedAndSealed(
        address indexed transmitter,
        bytes32 indexed packetId,
        bytes32 root,
        bytes signature
    );

    event PacketProposed(
        address indexed transmitter,
        bytes32 indexed packetId,
        bytes32 root
    );

    event MessageTransmitted(
        uint32 localChainSlug,
        address localPlug,
        uint32 dstChainSlug,
        address dstPlug,
        bytes32 msgId,
        uint256 msgGasLimit,
        uint256 executionFee,
        uint256 fees,
        bytes payload
    );

    function setUp() external {
        uint256[] memory transmitterPivateKeys = new uint256[](1);
        transmitterPivateKeys[0] = _transmitterPrivateKey;

        _dualChainSetup(transmitterPivateKeys);
        _deployPlugContracts();
        _configPlugContracts(index);

        bytes32 digest = keccak256(
            abi.encode(_a.chainSlug, gasPriceOracleNonce, sourceGasPrice)
        );
        bytes memory sig = _createSignature(digest, _transmitterPrivateKey);

        _a.gasPriceOracle__.setSourceGasPrice(
            gasPriceOracleNonce++,
            sourceGasPrice,
            sig
        );

        digest = keccak256(
            abi.encode(
                _a.chainSlug,
                _b.chainSlug,
                gasPriceOracleNonce,
                relativeGasPrice
            )
        );
        sig = _createSignature(digest, _transmitterPrivateKey);

        _a.gasPriceOracle__.setRelativeGasPrice(
            _b.chainSlug,
            gasPriceOracleNonce++,
            relativeGasPrice,
            sig
        );
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
        _sealOnSrc(_a, capacitor, sig_);

        vm.expectEmit(false, false, false, true);
        emit PacketProposed(_transmitter, packetId_, root_);
        _proposeOnDst(_b, sig_, packetId_, root_);

        assertEq(_b.socket__.packetIdRoots(packetId_), root_);
        assertEq(_b.socket__.rootProposedAt(packetId_), block.timestamp);
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

        _sealOnSrc(_a, capacitor, sig_);
        assertFalse(_b.socket__.isPacketProposed(packetId_));
        _proposeOnDst(_b, sig_, packetId_, root_);

        assertEq(_b.socket__.packetIdRoots(packetId_), root_);
        assertTrue(_b.socket__.isPacketProposed(packetId_));
    }

    function testProposeAPacketByInvalidAttester() external {
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

        vm.expectRevert(InvalidAttester.selector);

        _proposeOnDst(_b, sig_, packetId_, root_);
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
        (bytes32 packetId_, bytes32 root_) = sealAndPropose(capacitor);

        vm.expectRevert(AlreadyAttested.selector);
        _proposeOnDst(_b, sig_, packetId_, root_);
    }

    function sendOutboundMessage() internal {
        uint256 amount = 100;

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

            hoax(_plugOwner);
            srcCounter__.remoteAddOperation{
                value: switchboardFees +
                    socketFees +
                    verificationFee +
                    executionFee
            }(_b.chainSlug, amount, _msgGasLimit);
        }
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

        bytes32 msgId = _packMessageId(_a.chainSlug, 0);
        (bytes32 packetId, bytes32 root) = sealAndPropose(capacitor);
        _attestOnDst(address(_b.configs__[index].switchboard__), packetId);

        vm.expectEmit(true, false, false, false);
        emit ExecutionSuccess(msgId);

        _executePayloadOnDst(
            _b,
            _a.chainSlug,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            executionFee,
            root,
            payload,
            proof
        );

        assertEq(dstCounter__.counter(), amount);
        assertEq(srcCounter__.counter(), 0);
        assertTrue(_b.socket__.messageExecuted(msgId));

        vm.expectRevert(SocketDst.MessageAlreadyExecuted.selector);
        _executePayloadOnDst(
            _b,
            _a.chainSlug,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            executionFee,
            root,
            payload,
            proof
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

        bytes32 msgId = _packMessageId(_a.chainSlug, 0);
        (bytes32 packetId, bytes32 root) = sealAndPropose(capacitor);
        _attestOnDst(address(_b.configs__[index].switchboard__), packetId);

        vm.expectRevert(NotExecutor.selector);
        _executePayloadOnDstWithExecutor(
            _b,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            executionFee,
            root,
            uint256(1),
            payload,
            proof
        );
    }

    function getLatestSignature(
        ChainContext memory src_,
        address capacitor_,
        uint32 remoteChainSlug_,
        uint256 transmitterPrivateKey_
    ) public returns (bytes32 root, bytes32 packetId, bytes memory sig) {
        uint256 id;
        (root, id) = ICapacitor(capacitor_).getNextPacketToBeSealed();
        packetId = _getPackedId(capacitor_, src_.chainSlug, id);
        bytes32 digest = keccak256(
            abi.encode(remoteChainSlug_, packetId, root)
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

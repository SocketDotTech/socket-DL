// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Socket.sol";
import "../src/Notary/AdminNotary.sol";
import "../src/accumulators/SingleAccum.sol";
import "../src/deaccumulators/SingleDeaccum.sol";
import "../src/verifiers/AcceptWithTimeout.sol";
import "../src/utils/SignatureVerifier.sol";
import "../src/utils/Hasher.sol";
import "../src/examples/counter.sol";

contract HappyTest is Test {
    address constant _socketOwner = address(1);
    address constant _counterOwner = address(2);
    uint256 constant _attesterPrivateKey = uint256(3);
    address _attester;
    address constant _raju = address(4);
    address constant _pauser = address(5);
    bool constant _isFast = false;
    uint256 private _timeoutInSeconds = 0;
    uint256 private _waitTimeInSeconds = 0;
    struct ChainContext {
        uint256 chainId;
        Socket socket__;
        AdminNotary notary__;
        IAccumulator accum__;
        IDeaccumulator deaccum__;
        AcceptWithTimeout verifier__;
        Counter counter__;
        SignatureVerifier sigVerifier__;
        Hasher hasher__;
    }

    struct MessageContext {
        uint256 amount;
        bytes payload;
        bytes proof;
        uint256 msgId;
        bytes32 root;
        uint256 packetId;
        bytes sig;
    }

    ChainContext _a;
    ChainContext _b;

    function setUp() external {
        _a.chainId = 0x2013AA263;
        _b.chainId = 0x2013AA264;
        _deploySocketContracts();
        _initAttester();
        _deployPlugContracts();
        _configPlugContracts();
        _initPausers();
    }

    function testRemoteAddFromAtoB() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(keccak256("OP_ADD"), amount);
        bytes memory proof = abi.encode(0);

        hoax(_raju);
        _a.counter__.remoteAddOperation(_b.chainId, amount);
        // TODO: get nonce from event

        uint256 msgId = (uint64(_b.chainId) << 32) | 0;
        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_a);
        _verifyAndSealOnSrc(_a, sig);
        _submitRootOnDst(_a, _b, sig, packetId, root);
        _executePayloadOnDst(_a, _b, packetId, msgId, payload, proof);

        assertEq(_b.counter__.counter(), amount);
        assertEq(_a.counter__.counter(), 0);
    }

    function testRemoteAddFromBtoA() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(keccak256("OP_ADD"), amount);
        bytes memory proof = abi.encode(0);

        hoax(_raju);
        _b.counter__.remoteAddOperation(_a.chainId, amount);

        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_b);

        uint256 msgId = (uint64(_a.chainId) << 32) | 0;
        _verifyAndSealOnSrc(_b, sig);
        _submitRootOnDst(_b, _a, sig, packetId, root);
        _executePayloadOnDst(_b, _a, packetId, msgId, payload, proof);

        assertEq(_a.counter__.counter(), amount);
        assertEq(_b.counter__.counter(), 0);
    }

    function testRemoteAddAndSubtract() external {
        uint256 addAmount = 100;
        bytes memory addPayload = abi.encode(keccak256("OP_ADD"), addAmount);
        bytes memory addProof = abi.encode(0);
        uint256 addMsgId = (uint64(_b.chainId) << 32) | 0;

        uint256 subAmount = 40;
        bytes memory subPayload = abi.encode(keccak256("OP_SUB"), subAmount);
        bytes memory subProof = abi.encode(0);
        uint256 subMsgId = (uint64(_b.chainId) << 32) | 1;

        bytes32 root;
        uint256 packetId;
        bytes memory sig;

        hoax(_raju);
        _a.counter__.remoteAddOperation(_b.chainId, addAmount);

        (root, packetId, sig) = _getLatestSignature(_a);
        _verifyAndSealOnSrc(_a, sig);
        _submitRootOnDst(_a, _b, sig, packetId, root);
        _executePayloadOnDst(_a, _b, packetId, addMsgId, addPayload, addProof);

        hoax(_raju);
        _a.counter__.remoteSubOperation(_b.chainId, subAmount);

        (root, packetId, sig) = _getLatestSignature(_a);
        _verifyAndSealOnSrc(_a, sig);
        _submitRootOnDst(_a, _b, sig, packetId, root);
        _executePayloadOnDst(_a, _b, packetId, subMsgId, subPayload, subProof);

        assertEq(_b.counter__.counter(), addAmount - subAmount);
        assertEq(_a.counter__.counter(), 0);
    }

    function testMessagesOutOfOrderForSequentialConfig() external {
        _configPlugContracts();

        MessageContext memory m1;
        m1.amount = 100;
        m1.payload = abi.encode(keccak256("OP_ADD"), m1.amount);
        m1.proof = abi.encode(0);
        m1.msgId = (uint64(_b.chainId) << 32) | 0;

        hoax(_raju);
        _a.counter__.remoteAddOperation(_b.chainId, m1.amount);

        (m1.root, m1.packetId, m1.sig) = _getLatestSignature(_a);
        _verifyAndSealOnSrc(_a, m1.sig);
        _submitRootOnDst(_a, _b, m1.sig, m1.packetId, m1.root);

        MessageContext memory m2;
        m2.amount = 40;
        m2.payload = abi.encode(keccak256("OP_ADD"), m2.amount);
        m2.proof = abi.encode(0);
        m2.msgId = (uint64(_b.chainId) << 32) | 1;

        hoax(_raju);
        _a.counter__.remoteAddOperation(_b.chainId, m2.amount);

        (m2.root, m2.packetId, m2.sig) = _getLatestSignature(_a);
        _verifyAndSealOnSrc(_a, m2.sig);
        _submitRootOnDst(_a, _b, m2.sig, m2.packetId, m2.root);
    }

    function testMessagesOutOfOrderForNonSequentialConfig() external {
        _configPlugContracts();

        MessageContext memory m1;
        m1.amount = 100;
        m1.payload = abi.encode(keccak256("OP_ADD"), m1.amount);
        m1.proof = abi.encode(0);
        m1.msgId = (uint64(_b.chainId) << 32) | 0;

        hoax(_raju);
        _a.counter__.remoteAddOperation(_b.chainId, m1.amount);

        (m1.root, m1.packetId, m1.sig) = _getLatestSignature(_a);
        _verifyAndSealOnSrc(_a, m1.sig);
        _submitRootOnDst(_a, _b, m1.sig, m1.packetId, m1.root);

        MessageContext memory m2;
        m2.amount = 40;
        m2.payload = abi.encode(keccak256("OP_ADD"), m2.amount);
        m2.proof = abi.encode(0);
        m2.msgId = (uint64(_b.chainId) << 32) | 1;

        hoax(_raju);
        _a.counter__.remoteAddOperation(_b.chainId, m2.amount);

        (m2.root, m2.packetId, m2.sig) = _getLatestSignature(_a);
        _verifyAndSealOnSrc(_a, m2.sig);
        _submitRootOnDst(_a, _b, m2.sig, m2.packetId, m2.root);

        _executePayloadOnDst(
            _a,
            _b,
            m2.packetId,
            m2.msgId,
            m2.payload,
            m2.proof
        );
        _executePayloadOnDst(
            _a,
            _b,
            m1.packetId,
            m1.msgId,
            m1.payload,
            m1.proof
        );

        assertEq(_b.counter__.counter(), m1.amount + m2.amount);
        assertEq(_a.counter__.counter(), 0);
    }

    function testExecSameMessageTwice() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(keccak256("OP_ADD"), amount);
        bytes memory proof = abi.encode(0);
        uint256 msgId = (uint64(_b.chainId) << 32) | 0;

        hoax(_raju);
        _a.counter__.remoteAddOperation(_b.chainId, amount);
        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_a);
        _verifyAndSealOnSrc(_a, sig);
        _submitRootOnDst(_a, _b, sig, packetId, root);
        _executePayloadOnDst(_a, _b, packetId, msgId, payload, proof);

        vm.expectRevert(ISocket.MessageAlreadyExecuted.selector);
        _executePayloadOnDst(_a, _b, packetId, msgId, payload, proof);

        assertEq(_b.counter__.counter(), amount);
        assertEq(_a.counter__.counter(), 0);
    }

    function _deploySocketContracts() private {
        vm.startPrank(_socketOwner);

        _a.hasher__ = new Hasher();
        _b.hasher__ = new Hasher();

        _a.sigVerifier__ = new SignatureVerifier();
        _b.sigVerifier__ = new SignatureVerifier();

        _a.notary__ = new AdminNotary(
            address(_a.sigVerifier__),
            _a.chainId,
            _timeoutInSeconds,
            _waitTimeInSeconds
        );
        _b.notary__ = new AdminNotary(
            address(_b.sigVerifier__),
            _b.chainId,
            _timeoutInSeconds,
            _waitTimeInSeconds
        );

        // deploy socket
        _a.socket__ = new Socket(
            _a.chainId,
            address(_a.hasher__),
            address(_a.notary__)
        );
        _b.socket__ = new Socket(
            _b.chainId,
            address(_b.hasher__),
            address(_b.notary__)
        );

        // deploy accumulators
        _a.accum__ = new SingleAccum(
            address(_a.socket__),
            address(_a.notary__)
        );
        _b.accum__ = new SingleAccum(
            address(_b.socket__),
            address(_b.notary__)
        );

        _a.notary__.addAccumulator(address(_a.accum__), _b.chainId, _isFast);
        _b.notary__.addAccumulator(address(_b.accum__), _a.chainId, _isFast);

        // deploy deaccumulators
        _a.deaccum__ = new SingleDeaccum();
        _b.deaccum__ = new SingleDeaccum();

        vm.stopPrank();
    }

    function _initAttester() private {
        // deduce attester address from private key
        _attester = vm.addr(_attesterPrivateKey);

        vm.startPrank(_socketOwner);

        // grant attester role
        _a.notary__.grantAttesterRole(_b.chainId, _attester);
        _b.notary__.grantAttesterRole(_a.chainId, _attester);

        vm.stopPrank();
    }

    function _deployPlugContracts() private {
        vm.startPrank(_counterOwner);

        // deploy counters
        _a.counter__ = new Counter(address(_a.socket__));
        _b.counter__ = new Counter(address(_b.socket__));

        // deploy verifiers
        _a.verifier__ = new AcceptWithTimeout(
            address(_a.socket__),
            _counterOwner
        );
        _b.verifier__ = new AcceptWithTimeout(
            address(_b.socket__),
            _counterOwner
        );

        vm.stopPrank();
    }

    function _configPlugContracts() private {
        hoax(_counterOwner);
        _a.counter__.setSocketConfig(
            _b.chainId,
            address(_b.counter__),
            address(_a.accum__),
            address(_a.deaccum__),
            address(_a.verifier__)
        );

        hoax(_counterOwner);
        _b.counter__.setSocketConfig(
            _a.chainId,
            address(_a.counter__),
            address(_b.accum__),
            address(_b.deaccum__),
            address(_b.verifier__)
        );
    }

    function _initPausers() private {
        // add pausers
        hoax(_counterOwner);
        _a.verifier__.AddPauser(_pauser, _b.chainId);
        hoax(_counterOwner);
        _b.verifier__.AddPauser(_pauser, _a.chainId);

        // activate remote chains
        hoax(_pauser);
        _a.verifier__.Activate(_b.chainId);
        hoax(_pauser);
        _b.verifier__.Activate(_a.chainId);
    }

    function _getLatestSignature(ChainContext storage src_)
        private
        returns (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        )
    {
        (root, packetId) = src_.accum__.getNextPacket();
        bytes32 digest = keccak256(
            abi.encode(src_.chainId, address(src_.accum__), packetId, root)
        );

        (uint8 sigV, bytes32 sigR, bytes32 sigS) = vm.sign(
            _attesterPrivateKey,
            digest
        );
        sig = new bytes(65);
        bytes1 v32 = bytes1(sigV);

        assembly {
            mstore(add(sig, 96), v32)
            mstore(add(sig, 32), sigR)
            mstore(add(sig, 64), sigS)
        }
    }

    function _verifyAndSealOnSrc(ChainContext storage src_, bytes memory sig_)
        private
    {
        hoax(_attester);
        src_.notary__.verifyAndSeal(address(src_.accum__), sig_);
    }

    function _submitRootOnDst(
        ChainContext storage src_,
        ChainContext storage dst_,
        bytes memory sig_,
        uint256 packetId_,
        bytes32 root_
    ) private {
        hoax(_raju);
        dst_.notary__.propose(
            src_.chainId,
            address(src_.accum__),
            packetId_,
            root_,
            sig_
        );
    }

    function _executePayloadOnDst(
        ChainContext storage src_,
        ChainContext storage dst_,
        uint256 packetId_,
        uint256 msgId_,
        bytes memory payload_,
        bytes memory proof_
    ) private {
        hoax(_raju);
        dst_.socket__.execute(
            src_.chainId,
            address(dst_.counter__),
            msgId_,
            _attester,
            address(src_.accum__),
            packetId_,
            payload_,
            proof_
        );
    }
}

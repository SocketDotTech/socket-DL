// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Socket.sol";
import "../src/accumulators/SingleAccum.sol";
import "../src/deaccumulators/SingleDeaccum.sol";
import "../src/verifiers/AcceptWithTimeout.sol";
import "../src/examples/counter.sol";

contract HappyTest is Test {
    address constant _socketOwner = address(1);
    address constant _counterOwner = address(2);
    uint256 constant _signerPrivateKey = uint256(3);
    address _signer;
    address constant _raju = address(4);
    address constant _pauser = address(5);

    uint256 constant _minBondAmount = 100e18;
    uint256 constant _bondClaimDelay = 1 weeks;

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct ChainContext {
        uint256 chainId;
        ISocket socket__;
        IAccumulator accum__;
        IDeaccumulator deaccum__;
        AcceptWithTimeout verifier__;
        Counter counter__;
    }

    ChainContext _a;
    ChainContext _b;

    function setUp() external {
        _a.chainId = 0x2013AA263;
        _b.chainId = 0x2013AA264;
        _deploySocketContracts();
        _initSigner();
        _deployPlugContracts();
        _configPlugContracts(true);
        _initPausers();
    }

    function _deploySocketContracts() private {
        vm.startPrank(_socketOwner);

        // deploy socket
        _a.socket__ = new Socket(_minBondAmount, _bondClaimDelay, _a.chainId);
        _b.socket__ = new Socket(_minBondAmount, _bondClaimDelay, _b.chainId);

        // deploy accumulators
        _a.accum__ = new SingleAccum(address(_a.socket__));
        _b.accum__ = new SingleAccum(address(_b.socket__));

        // deploy deaccumulators
        _a.deaccum__ = new SingleDeaccum();
        _b.deaccum__ = new SingleDeaccum();

        vm.stopPrank();
    }

    function _initSigner() private {
        // deduce signer address from private key
        _signer = vm.addr(_signerPrivateKey);

        // bond signer
        hoax(_signer);
        _a.socket__.addBond{value: _minBondAmount}();
        hoax(_signer);
        _b.socket__.addBond{value: _minBondAmount}();

        // grant signer role
        hoax(_socketOwner);
        _a.socket__.grantSignerRole(_b.chainId, _signer);
        hoax(_socketOwner);
        _b.socket__.grantSignerRole(_a.chainId, _signer);
    }

    function _deployPlugContracts() private {
        vm.startPrank(_counterOwner);

        // deploy counters
        _a.counter__ = new Counter(address(_a.socket__));
        _b.counter__ = new Counter(address(_b.socket__));

        // deploy verifiers
        _a.verifier__ = new AcceptWithTimeout(
            0,
            address(_a.socket__),
            _counterOwner
        );
        _b.verifier__ = new AcceptWithTimeout(
            0,
            address(_b.socket__),
            _counterOwner
        );

        vm.stopPrank();
    }

    function _configPlugContracts(bool isSequential_) private {
        hoax(_counterOwner);
        _a.counter__.setSocketConfig(
            _b.chainId,
            address(_b.counter__),
            address(_a.accum__),
            address(_a.deaccum__),
            address(_a.verifier__),
            isSequential_
        );

        hoax(_counterOwner);
        _b.counter__.setSocketConfig(
            _a.chainId,
            address(_a.counter__),
            address(_b.accum__),
            address(_b.deaccum__),
            address(_b.verifier__),
            isSequential_
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

    function testRemoteAddFromAtoB() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(keccak256("OP_ADD"), amount);
        bytes memory proof = abi.encode(0);

        hoax(_raju);
        _a.counter__.remoteAddOperation(_b.chainId, amount);
        // TODO: get nonce from event
        (
            bytes32 root,
            uint256 batchId,
            Signature memory sig
        ) = _getLatestSignature(_a);
        _submitSignatureOnSrc(_a, sig);
        _submitRootOnDst(_a, _b, sig, batchId, root);
        _executePayloadOnDst(_a, _b, batchId, 0, payload, proof);

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
            uint256 batchId,
            Signature memory sig
        ) = _getLatestSignature(_b);
        _submitSignatureOnSrc(_b, sig);
        _submitRootOnDst(_b, _a, sig, batchId, root);
        _executePayloadOnDst(_b, _a, batchId, 0, payload, proof);

        assertEq(_a.counter__.counter(), amount);
        assertEq(_b.counter__.counter(), 0);
    }

    function testExecSamePacketTwice() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(keccak256("OP_ADD"), amount);
        bytes memory proof = abi.encode(0);

        hoax(_raju);
        _a.counter__.remoteAddOperation(_b.chainId, amount);
        (
            bytes32 root,
            uint256 batchId,
            Signature memory sig
        ) = _getLatestSignature(_a);
        _submitSignatureOnSrc(_a, sig);
        _submitRootOnDst(_a, _b, sig, batchId, root);
        _executePayloadOnDst(_a, _b, batchId, 0, payload, proof);

        vm.expectRevert(ISocket.PacketAlreadyExecuted.selector);
        _executePayloadOnDst(_a, _b, batchId, 0, payload, proof);

        assertEq(_b.counter__.counter(), amount);
        assertEq(_a.counter__.counter(), 0);
    }

    function _getLatestSignature(ChainContext storage src_)
        private
        returns (
            bytes32 root,
            uint256 batchId,
            Signature memory sig
        )
    {
        (root, batchId) = src_.accum__.getNextBatch();
        bytes32 digest = keccak256(
            abi.encode(src_.chainId, address(src_.accum__), batchId, root)
        );
        (uint8 sigV, bytes32 sigR, bytes32 sigS) = vm.sign(
            _signerPrivateKey,
            digest
        );
        sig = Signature(sigV, sigR, sigS);
    }

    function _submitSignatureOnSrc(
        ChainContext storage src_,
        Signature memory sig_
    ) private {
        hoax(_raju);
        src_.socket__.submitSignature(
            sig_.v,
            sig_.r,
            sig_.s,
            address(src_.accum__)
        );
    }

    function _submitRootOnDst(
        ChainContext storage src_,
        ChainContext storage dst_,
        Signature memory sig_,
        uint256 batchId_,
        bytes32 root_
    ) private {
        hoax(_raju);
        dst_.socket__.submitRemoteRoot(
            sig_.v,
            sig_.r,
            sig_.s,
            src_.chainId,
            address(src_.accum__),
            batchId_,
            root_
        );
    }

    function _executePayloadOnDst(
        ChainContext storage src_,
        ChainContext storage dst_,
        uint256 batchId_,
        uint256 nonce_,
        bytes memory payload_,
        bytes memory proof_
    ) private {
        hoax(_raju);
        dst_.socket__.execute(
            src_.chainId,
            address(dst_.counter__),
            nonce_,
            _signer,
            address(src_.accum__),
            batchId_,
            payload_,
            proof_
        );
    }
}

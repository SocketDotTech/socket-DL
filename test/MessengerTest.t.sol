// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Socket.sol";
import "../src/Notary/AdminNotary.sol";
import "../src/accumulators/SingleAccum.sol";
import "../src/deaccumulators/SingleDeaccum.sol";
import "../src/verifiers/AcceptWithTimeout.sol";
import "../src/examples/Messenger.sol";
import "../src/utils/SignatureVerifier.sol";
import "../src/utils/Hasher.sol";

contract PingPongTest is Test {
    bytes32 private constant _PING = keccak256("PING");
    bytes32 private constant _PONG = keccak256("PONG");
    uint256 private constant _attesterPrivateKey = uint256(3);

    address private constant _socketOwner = address(1);
    address private constant _counterOwner = address(2);
    address private constant _raju = address(4);
    address private constant _pauser = address(5);
    address private _attester;
    bool private _isFast = false;

    bytes private constant _PROOF = abi.encode(0);
    bytes private _payloadPing;
    bytes private _payloadPong;

    struct ChainContext {
        uint256 chainId;
        Socket socket__;
        AdminNotary notary__;
        IAccumulator accum__;
        IDeaccumulator deaccum__;
        AcceptWithTimeout verifier__;
        Messenger messenger__;
        SignatureVerifier sigVerifier__;
        Hasher hasher__;
    }

    struct MessageContext {
        uint256 amount;
        bytes payload;
        bytes proof;
        uint256 nonce;
        bytes32 root;
        uint256 packetId;
        bytes sig;
    }

    ChainContext private _a;
    ChainContext private _b;

    function setUp() external {
        _a.chainId = 0x2013AA263;
        _b.chainId = 0x2013AA264;
        _deploySocketContracts();
        _initAttester();
        _deployPlugContracts();
        _configPlugContracts(true);
        _initPausers();

        _payloadPing = abi.encode(_a.chainId, _PING);
        _payloadPong = abi.encode(_b.chainId, _PONG);
    }

    function _verifyAToB(uint256 nonce_) internal {
        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_a);

        _verifyAndSealOnSrc(_a, sig);
        _submitRootOnDst(_a, _b, sig, packetId, root);
        _executePayloadOnDst(_a, _b, packetId, nonce_, _payloadPing, _PROOF);

        assertEq(_b.messenger__.message(), _PING);
    }

    function _verifyBToA(uint256 nonce_) internal {
        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_b);

        _verifyAndSealOnSrc(_b, sig);
        _submitRootOnDst(_b, _a, sig, packetId, root);
        _executePayloadOnDst(_b, _a, packetId, nonce_, _payloadPong, _PROOF);

        assertEq(_a.messenger__.message(), _PONG);
    }

    function _reset() internal {
        _b.messenger__.sendLocalMessage(bytes32(0));
        _a.messenger__.sendLocalMessage(bytes32(0));
    }

    function testPingPong() external {
        hoax(_raju);
        _a.messenger__.sendRemoteMessage(_b.chainId, _PING);

        uint256 iterations = 5;
        for (uint256 index = 0; index < iterations; index++) {
            _verifyAToB(index);
            _verifyBToA(index);
            _reset();
        }
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
            0,
            0
        );
        _b.notary__ = new AdminNotary(
            address(_b.sigVerifier__),
            _b.chainId,
            0,
            0
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
        _a.messenger__ = new Messenger(address(_a.socket__), _a.chainId);
        _b.messenger__ = new Messenger(address(_b.socket__), _b.chainId);

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

    function _configPlugContracts(bool isSequential_) private {
        hoax(_counterOwner);
        _a.messenger__.setSocketConfig(
            _b.chainId,
            address(_b.messenger__),
            address(_a.accum__),
            address(_a.deaccum__),
            address(_a.verifier__),
            isSequential_
        );

        hoax(_counterOwner);
        _b.messenger__.setSocketConfig(
            _a.chainId,
            address(_a.messenger__),
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
        bytes1 v = bytes1(sigV);

        assembly {
            mstore(add(sig, 32), sigR)
            mstore(add(sig, 64), sigS)
            mstore(add(sig, 96), v)
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
        uint256 nonce_,
        bytes memory payload_,
        bytes memory proof_
    ) private {
        hoax(_raju);
        dst_.socket__.execute(
            src_.chainId,
            address(dst_.messenger__),
            nonce_,
            _attester,
            address(src_.accum__),
            packetId_,
            payload_,
            proof_
        );
    }
}

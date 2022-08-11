// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Socket.sol";
import "../src/Notary/AdminNotary.sol";
import "../src/accumulators/SingleAccum.sol";
import "../src/deaccumulators/SingleDeaccum.sol";
import "../src/verifiers/AcceptWithTimeout.sol";
import "../src/examples/Messenger.sol";

contract HappyTest is Test {
    address constant _socketOwner = address(1);
    address constant _counterOwner = address(2);
    uint256 constant _attesterPrivateKey = uint256(3);
    address _attester;
    address constant _raju = address(4);
    address constant _pauser = address(5);
    bool constant _isFast = false;

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct ChainContext {
        uint256 chainId;
        Socket socket__;
        Notary notary__;
        IAccumulator accum__;
        IDeaccumulator deaccum__;
        AcceptWithTimeout verifier__;
        Messenger messenger__;
    }

    struct MessageContext {
        uint256 amount;
        bytes payload;
        bytes proof;
        uint256 nonce;
        bytes32 root;
        uint256 packetId;
        Signature sig;
    }

    ChainContext _a;
    ChainContext _b;

    function setUp() external {
        _a.chainId = 0x2013AA263;
        _b.chainId = 0x2013AA264;
        _deploySocketContracts();
        _initAttester();
        _deployPlugContracts();
        _configPlugContracts(true);
        _initPausers();
    }

    function _sendPing(uint256 nonce) internal {
        bytes32 hashedMessage = keccak256("PING");
        bytes memory payload = abi.encode(hashedMessage);
        bytes memory proof = abi.encode(0);

        hoax(_raju);
        _a.messenger__.sendRemoteMessage(_b.chainId, hashedMessage);

        (
            bytes32 root,
            uint256 packetId,
            Signature memory sig
        ) = _getLatestSignature(_a);

        _submitSignatureOnSrc(_a, sig);
        _submitRootOnDst(_a, _b, sig, packetId, root);
        _executePayloadOnDst(_a, _b, packetId, nonce, payload, proof);

        assertEq(_b.messenger__.message(), hashedMessage);
    }

    function _sendPong(uint256 nonce) internal {
        bytes32 hashedMessage = keccak256("PONG");
        bytes memory payload = abi.encode(hashedMessage);
        bytes memory proof = abi.encode(0);

        hoax(_raju);
        _b.messenger__.sendRemoteMessage(_a.chainId, hashedMessage);

        (
            bytes32 root,
            uint256 packetId,
            Signature memory sig
        ) = _getLatestSignature(_b);

        _submitSignatureOnSrc(_b, sig);
        _submitRootOnDst(_b, _a, sig, packetId, root);
        _executePayloadOnDst(_b, _a, packetId, nonce, payload, proof);

        assertEq(_a.messenger__.message(), hashedMessage);
    }

    function _reset() internal {
        _b.messenger__.sendLocalMessage(bytes32(0));
        _a.messenger__.sendLocalMessage(bytes32(0));
    }

    function testPingPong() external {
        uint256 iterations = 5;
        for (uint256 index = 0; index < iterations; index++) {
            _sendPing(index);
            _sendPong(index);
            _reset();
        }
    }

    function _deploySocketContracts() private {
        vm.startPrank(_socketOwner);

        // deploy socket
        _a.socket__ = new Socket(_a.chainId);
        _b.socket__ = new Socket(_b.chainId);

        _a.notary__ = new Notary(_a.chainId);
        _b.notary__ = new Notary(_b.chainId);

        _a.socket__.setNotary(address(_a.notary__));
        _b.socket__.setNotary(address(_b.notary__));

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
        _a.messenger__ = new Messenger(address(_a.socket__));
        _b.messenger__ = new Messenger(address(_b.socket__));

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
            Signature memory sig
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
        sig = Signature(sigV, sigR, sigS);
    }

    function _submitSignatureOnSrc(
        ChainContext storage src_,
        Signature memory sig_
    ) private {
        hoax(_attester);
        src_.notary__.submitSignature(
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
        uint256 packetId_,
        bytes32 root_
    ) private {
        hoax(_raju);
        dst_.notary__.submitRemoteRoot(
            sig_.v,
            sig_.r,
            sig_.s,
            src_.chainId,
            address(src_.accum__),
            packetId_,
            root_
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

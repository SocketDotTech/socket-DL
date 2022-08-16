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

contract HappyTest is Test {
    address constant _socketOwner = address(1);
    address constant _counterOwner = address(2);
    uint256 constant _signerPrivateKey = uint256(3);
    address _signer;
    address constant _raju = address(4);
    address constant _pauser = address(5);
    bytes32 public constant ATTESTER_ROLE = keccak256("ATTESTER_ROLE");

    struct ChainContext {
        uint256 chainId;
        Socket socket__;
        Notary notary__;
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

    function _sendPing(uint256 nonce) internal {
        bytes32 hashedMessage = keccak256("PING");
        bytes memory payload = abi.encode(hashedMessage);
        bytes memory proof = abi.encode(0);

        hoax(_raju);
        _a.messenger__.sendRemoteMessage(_b.chainId, hashedMessage);

        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
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
            bytes memory sig
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

        _a.hasher__ = new Hasher();
        _b.hasher__ = new Hasher();

        // deploy socket
        _a.socket__ = new Socket(_a.chainId, address(_a.hasher__));
        _b.socket__ = new Socket(_b.chainId, address(_b.hasher__));

        _a.sigVerifier__ = new SignatureVerifier();
        _b.sigVerifier__ = new SignatureVerifier();

        _a.notary__ = new Notary(_a.chainId, address(_a.sigVerifier__));
        _b.notary__ = new Notary(_b.chainId, address(_b.sigVerifier__));

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

        // deploy deaccumulators
        _a.deaccum__ = new SingleDeaccum();
        _b.deaccum__ = new SingleDeaccum();

        vm.stopPrank();
    }

    function _initSigner() private {
        // deduce signer address from private key
        _signer = vm.addr(_signerPrivateKey);

        vm.startPrank(_socketOwner);

        _a.notary__.grantRole(ATTESTER_ROLE, _signer);
        _b.notary__.grantRole(ATTESTER_ROLE, _signer);

        // grant signer role
        _a.notary__.grantSignerRole(_b.chainId, _signer);
        _b.notary__.grantSignerRole(_a.chainId, _signer);

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
            bytes memory sig
        )
    {
        (root, packetId) = src_.accum__.getNextPacket();
        bytes32 digest = keccak256(
            abi.encode(src_.chainId, address(src_.accum__), packetId, root)
        );
        (uint8 sigV, bytes32 sigR, bytes32 sigS) = vm.sign(
            _signerPrivateKey,
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

    function _submitSignatureOnSrc(ChainContext storage src_, bytes memory sig_)
        private
    {
        hoax(_signer);
        src_.notary__.submitSignature(address(src_.accum__), sig_);
    }

    function _submitRootOnDst(
        ChainContext storage src_,
        ChainContext storage dst_,
        bytes memory sig_,
        uint256 packetId_,
        bytes32 root_
    ) private {
        hoax(_raju);
        dst_.notary__.submitRemoteRoot(
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
            _signer,
            address(src_.accum__),
            packetId_,
            payload_,
            proof_
        );
    }
}

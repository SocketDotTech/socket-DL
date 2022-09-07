// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Notary/AdminNotary.sol";
import "../src/interfaces/IAccumulator.sol";
import "../src/utils/SignatureVerifier.sol";

contract AdminNotaryTest is Test {
    address constant _owner = address(1);
    uint256 constant _attesterPrivateKey = uint256(2);
    uint256 constant _altAttesterPrivateKey = uint256(3);

    address constant _accum = address(4);
    bytes32 constant _root = bytes32(uint256(5));
    uint256 constant _packetId = uint256(6);
    address _attester;
    address _altAttester;
    address constant _raju = address(7);
    bytes32 constant _altRoot = bytes32(uint256(8));

    uint256 constant _chainId = 0x2013AA263;
    uint256 constant _remoteChainId = 0x2013AA264;
    bool constant _isFast = false;

    AdminNotary _notary;
    SignatureVerifier _sigVerifier;

    function setUp() external {
        _attester = vm.addr(_attesterPrivateKey);
        _altAttester = vm.addr(_altAttesterPrivateKey);
        _sigVerifier = new SignatureVerifier();

        hoax(_owner);
        _notary = new AdminNotary(address(_sigVerifier), _chainId);
    }

    function testDeployment() external {
        assertEq(_notary.owner(), _owner);
        assertEq(_notary.chainId(), _chainId);
    }

    function testGrantAttesterRole() external {
        vm.startPrank(_owner);
        _notary.grantAttesterRole(_remoteChainId, _attester);

        assertTrue(_notary.hasRole(bytes32(_remoteChainId), _attester));
        vm.expectRevert(INotary.AttesterExists.selector);
        _notary.grantAttesterRole(_remoteChainId, _attester);

        assertEq(_notary.totalAttestors(_remoteChainId), 1);
    }

    function testRevokeAttesterRole() external {
        vm.startPrank(_owner);
        vm.expectRevert(INotary.AttesterNotFound.selector);
        _notary.revokeAttesterRole(_remoteChainId, _attester);

        _notary.grantAttesterRole(_remoteChainId, _attester);
        _notary.revokeAttesterRole(_remoteChainId, _attester);

        assertFalse(_notary.hasRole(bytes32(_remoteChainId), _attester));
        assertEq(_notary.totalAttestors(_remoteChainId), 0);
    }

    function testAddAccumulator() external {
        vm.startPrank(_owner);
        // should add accumulator
        _notary.addAccumulator(_accum, _remoteChainId, true);
    }

    function testConfirmRootSlowPath() external {
        hoax(_owner);
        _notary.addAccumulator(_accum, _remoteChainId, false);
        hoax(_owner);
        _notary.grantAttesterRole(_remoteChainId, _attester);
        hoax(_owner);
        _notary.grantAttesterRole(_remoteChainId, _altAttester);

        bytes32 digest = keccak256(
            abi.encode(_remoteChainId, _accum, _packetId, _root)
        );

        // status not proposed
        assertEq(
            uint256(_notary.getPacketStatus(_accum, _remoteChainId, _packetId)),
            0
        );

        hoax(_raju);
        _notary.propose(
            _remoteChainId,
            _accum,
            _packetId,
            _root,
            _getSignature(digest, _attesterPrivateKey)
        );

        // status confirmed
        assertEq(
            uint256(_notary.getPacketStatus(_accum, _remoteChainId, _packetId)),
            3
        );
    }

    function testConfirmRootFastPath() external {
        hoax(_owner);
        _notary.addAccumulator(_accum, _remoteChainId, true);
        hoax(_owner);
        _notary.grantAttesterRole(_remoteChainId, _attester);
        hoax(_owner);
        _notary.grantAttesterRole(_remoteChainId, _altAttester);

        bytes32 digest = keccak256(
            abi.encode(_remoteChainId, _accum, _packetId, _root)
        );
        // status not-proposed
        assertEq(
            uint256(_notary.getPacketStatus(_accum, _remoteChainId, _packetId)),
            0
        );

        hoax(_raju);
        _notary.propose(
            _remoteChainId,
            _accum,
            _packetId,
            _root,
            _getSignature(digest, _attesterPrivateKey)
        );

        // status proposed
        assertEq(
            uint256(_notary.getPacketStatus(_accum, _remoteChainId, _packetId)),
            1
        );

        hoax(_raju);
        _notary.confirmRoot(
            _remoteChainId,
            _accum,
            _packetId,
            _root,
            _getSignature(digest, _altAttesterPrivateKey)
        );

        // status confirmed
        assertEq(
            uint256(_notary.getPacketStatus(_accum, _remoteChainId, _packetId)),
            3
        );
    }

    function testVerifyAndSeal() external {
        hoax(_owner);
        _notary.addAccumulator(_accum, _remoteChainId, _isFast);

        hoax(_owner);
        _notary.grantAttesterRole(_remoteChainId, _attester);

        vm.mockCall(
            _accum,
            abi.encodeWithSelector(IAccumulator.sealPacket.selector),
            abi.encode(_root, _packetId)
        );

        bytes32 digest = keccak256(
            abi.encode(_chainId, _accum, _packetId, _root)
        );

        hoax(_attester);
        _notary.verifyAndSeal(
            _accum,
            _remoteChainId,
            _getSignature(digest, _attesterPrivateKey)
        );

        hoax(_attester);
        vm.expectRevert(INotary.InvalidAttester.selector);
        _notary.verifyAndSeal(
            _accum,
            _remoteChainId,
            _getSignature(digest, _altAttesterPrivateKey)
        );
    }

    function testChallengeSignature() external {
        hoax(_owner);
        _notary.addAccumulator(_accum, _remoteChainId, _isFast);

        hoax(_owner);
        _notary.grantAttesterRole(_remoteChainId, _attester);

        vm.mockCall(
            _accum,
            abi.encodeWithSelector(IAccumulator.sealPacket.selector),
            abi.encode(_root, _packetId)
        );

        bytes32 digest = keccak256(
            abi.encode(_chainId, _accum, _packetId, _root)
        );

        hoax(_attester);
        _notary.verifyAndSeal(
            _accum,
            _remoteChainId,
            _getSignature(digest, _attesterPrivateKey)
        );

        bytes32 altDigest = keccak256(
            abi.encode(_chainId, _accum, _packetId, _altRoot)
        );

        hoax(_raju);
        _notary.challengeSignature(
            _accum,
            _altRoot,
            _packetId,
            _getSignature(altDigest, _attesterPrivateKey)
        );
    }

    function testSubmitRemoteRoot() external {
        bytes32 digest = keccak256(
            abi.encode(_remoteChainId, _accum, _packetId, _root)
        );

        hoax(_raju);
        vm.expectRevert(INotary.InvalidAttester.selector);
        _notary.propose(
            _remoteChainId,
            _accum,
            _packetId,
            _root,
            _getSignature(digest, _attesterPrivateKey)
        );

        hoax(_owner);
        _notary.grantAttesterRole(_remoteChainId, _attester);

        hoax(_raju);
        _notary.propose(
            _remoteChainId,
            _accum,
            _packetId,
            _root,
            _getSignature(digest, _attesterPrivateKey)
        );

        assertEq(
            _notary.getRemoteRoot(_remoteChainId, _accum, _packetId),
            _root
        );

        assertEq(
            _notary.getConfirmations(_accum, _remoteChainId, _packetId),
            1
        );

        assertEq(
            _notary.getRemoteRoot(_remoteChainId, _accum, _packetId),
            _root
        );

        // status confirmed
        assertEq(
            uint256(_notary.getPacketStatus(_accum, _remoteChainId, _packetId)),
            3
        );

        hoax(_raju);
        vm.expectRevert(INotary.AlreadyProposed.selector);
        _notary.propose(
            _remoteChainId,
            _accum,
            _packetId,
            _root,
            _getSignature(digest, _attesterPrivateKey)
        );
    }

    function testSubmitRemoteRootWithoutRole() external {
        bytes32 digest = keccak256(
            abi.encode(_remoteChainId, _accum, _packetId, _root)
        );

        hoax(_owner);
        _notary.grantAttesterRole(_remoteChainId, _attester);

        hoax(_raju);
        _notary.propose(
            _remoteChainId,
            _accum,
            _packetId,
            _root,
            _getSignature(digest, _attesterPrivateKey)
        );
    }

    function _getSignature(bytes32 digest, uint256 privateKey_)
        internal
        returns (bytes memory sig)
    {
        (uint8 sigV, bytes32 sigR, bytes32 sigS) = vm.sign(privateKey_, digest);

        sig = new bytes(65);
        bytes1 v32 = bytes1(sigV);

        assembly {
            mstore(add(sig, 96), v32)
            mstore(add(sig, 32), sigR)
            mstore(add(sig, 64), sigS)
        }
    }
}

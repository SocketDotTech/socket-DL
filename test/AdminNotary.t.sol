// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Setup.t.sol";

contract AdminNotaryTest is Setup {
    address constant _accum = address(4);
    bytes32 constant _root = bytes32(uint256(5));
    uint256 constant _packetId = uint256(6);

    bytes32 constant _altRoot = bytes32(uint256(8));
    uint256 _chainId = 0x2013AA263;
    uint256 _remoteChainId = 0x2013AA264;

    ChainContext cc;

    function setUp() external {
        uint256[] memory attesters = new uint256[](2);
        attesters[0] = _attesterPrivateKey;
        attesters[1] = _altAttesterPrivateKey;

        _attester = vm.addr(_attesterPrivateKey);
        _altAttester = vm.addr(_altAttesterPrivateKey);

        (cc.sigVerifier__, cc.notary__) = _deployNotary(_chainId, _socketOwner);
    }

    function testDeployment() external {
        assertEq(cc.notary__.owner(), _socketOwner);
        assertEq(cc.notary__.chainId(), _chainId);
        assertEq(
            address(cc.notary__.signatureVerifier()),
            address(cc.sigVerifier__)
        );
    }

    function testSetSignatureVerifier() external {
        address newSigVerifier = address(9);

        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        cc.notary__.setSignatureVerifier(newSigVerifier);

        hoax(_socketOwner);
        cc.notary__.setSignatureVerifier(newSigVerifier);
        assertEq(address(cc.notary__.signatureVerifier()), newSigVerifier);
    }

    function testGrantAttesterRole() external {
        vm.startPrank(_socketOwner);
        cc.notary__.grantAttesterRole(_remoteChainId, _attester);

        assertTrue(cc.notary__.hasRole(bytes32(_remoteChainId), _attester));

        vm.expectRevert(INotary.AttesterExists.selector);
        cc.notary__.grantAttesterRole(_remoteChainId, _attester);

        assertEq(cc.notary__.totalAttestors(_remoteChainId), 1);
    }

    function testRevokeAttesterRole() external {
        vm.startPrank(_socketOwner);
        vm.expectRevert(INotary.AttesterNotFound.selector);
        cc.notary__.revokeAttesterRole(_remoteChainId, _attester);

        cc.notary__.grantAttesterRole(_remoteChainId, _attester);
        cc.notary__.revokeAttesterRole(_remoteChainId, _attester);

        assertFalse(cc.notary__.hasRole(bytes32(_remoteChainId), _attester));
        assertEq(cc.notary__.totalAttestors(_remoteChainId), 0);
    }

    function testAddAccumulator() external {
        uint256 accumId = (uint256(uint160(_accum)) << 32) | _remoteChainId;
        assertEq(cc.notary__.isFast(accumId), false);

        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        cc.notary__.addAccumulator(_accum, _remoteChainId, true);

        vm.startPrank(_socketOwner);
        // should add accumulator
        cc.notary__.addAccumulator(_accum, _remoteChainId, true);

        assertEq(cc.notary__.isFast(accumId), true);
    }

    function testSeal() external {
        hoax(_socketOwner);
        cc.notary__.addAccumulator(_accum, _remoteChainId, _isFast);

        hoax(_socketOwner);
        cc.notary__.grantAttesterRole(_remoteChainId, _attester);

        vm.mockCall(
            _accum,
            abi.encodeWithSelector(IAccumulator.sealPacket.selector),
            abi.encode(_root, _packetId)
        );

        bytes32 digest = keccak256(
            abi.encode(_chainId, _accum, _packetId, _root)
        );

        hoax(_attester);
        cc.notary__.seal(
            _accum,
            _remoteChainId,
            _getSignature(digest, _attesterPrivateKey)
        );

        hoax(_attester);
        vm.expectRevert(INotary.InvalidAttester.selector);
        cc.notary__.seal(
            _accum,
            _remoteChainId,
            _getSignature(digest, _altAttesterPrivateKey)
        );
    }

    function testChallengeSignature() external {
        hoax(_socketOwner);
        cc.notary__.addAccumulator(_accum, _remoteChainId, _isFast);

        hoax(_socketOwner);
        cc.notary__.grantAttesterRole(_remoteChainId, _attester);

        vm.mockCall(
            _accum,
            abi.encodeWithSelector(IAccumulator.sealPacket.selector),
            abi.encode(_root, _packetId)
        );

        bytes32 digest = keccak256(
            abi.encode(_chainId, _accum, _packetId, _root)
        );

        hoax(_attester);
        cc.notary__.seal(
            _accum,
            _remoteChainId,
            _getSignature(digest, _attesterPrivateKey)
        );

        bytes32 altDigest = keccak256(
            abi.encode(_chainId, _accum, _packetId, _altRoot)
        );

        hoax(_raju);
        cc.notary__.challengeSignature(
            _accum,
            _altRoot,
            _packetId,
            _getSignature(altDigest, _attesterPrivateKey)
        );
    }

    function testConfirmRootSlowPath() external {
        hoax(_socketOwner);
        cc.notary__.addAccumulator(_accum, _remoteChainId, false);
        hoax(_socketOwner);
        cc.notary__.grantAttesterRole(_remoteChainId, _attester);

        bytes32 digest = keccak256(
            abi.encode(_remoteChainId, _accum, _packetId, _root)
        );

        // status not proposed
        assertEq(
            uint256(
                cc.notary__.getPacketStatus(_accum, _remoteChainId, _packetId)
            ),
            0
        );

        hoax(_raju);
        cc.notary__.propose(
            _remoteChainId,
            _accum,
            _packetId,
            _root,
            _getSignature(digest, _attesterPrivateKey)
        );

        // status confirmed
        vm.warp(block.timestamp + _slowAccumWaitTime);
        assertEq(
            uint256(
                cc.notary__.getPacketStatus(_accum, _remoteChainId, _packetId)
            ),
            3
        );
    }

    function testConfirmRootFastPath() external {
        hoax(_socketOwner);
        cc.notary__.addAccumulator(_accum, _remoteChainId, true);
        hoax(_socketOwner);
        cc.notary__.grantAttesterRole(_remoteChainId, _attester);
        hoax(_socketOwner);
        cc.notary__.grantAttesterRole(_remoteChainId, _altAttester);

        bytes32 digest = keccak256(
            abi.encode(_remoteChainId, _accum, _packetId, _root)
        );
        // status not-proposed
        assertEq(
            uint256(
                cc.notary__.getPacketStatus(_accum, _remoteChainId, _packetId)
            ),
            0
        );

        hoax(_raju);
        cc.notary__.propose(
            _remoteChainId,
            _accum,
            _packetId,
            _root,
            _getSignature(digest, _attesterPrivateKey)
        );

        // status proposed
        assertEq(
            uint256(
                cc.notary__.getPacketStatus(_accum, _remoteChainId, _packetId)
            ),
            1
        );

        hoax(_raju);
        vm.expectRevert(INotary.AlreadyAttested.selector);
        cc.notary__.confirmRoot(
            _remoteChainId,
            _accum,
            _packetId,
            _root,
            _getSignature(digest, _attesterPrivateKey)
        );

        hoax(_raju);
        cc.notary__.confirmRoot(
            _remoteChainId,
            _accum,
            _packetId,
            _root,
            _getSignature(digest, _altAttesterPrivateKey)
        );

        // status confirmed
        assertEq(
            uint256(
                cc.notary__.getPacketStatus(_accum, _remoteChainId, _packetId)
            ),
            3
        );
    }

    function testPropose() external {
        bytes32 digest = keccak256(
            abi.encode(_remoteChainId, _accum, _packetId, _root)
        );

        hoax(_raju);
        vm.expectRevert(INotary.InvalidAttester.selector);
        cc.notary__.propose(
            _remoteChainId,
            _accum,
            _packetId,
            _root,
            _getSignature(digest, _attesterPrivateKey)
        );

        hoax(_socketOwner);
        cc.notary__.grantAttesterRole(_remoteChainId, _attester);

        hoax(_raju);
        cc.notary__.propose(
            _remoteChainId,
            _accum,
            _packetId,
            _root,
            _getSignature(digest, _attesterPrivateKey)
        );

        assertEq(
            cc.notary__.getRemoteRoot(_remoteChainId, _accum, _packetId),
            _root
        );

        assertEq(
            cc.notary__.getConfirmations(_accum, _remoteChainId, _packetId),
            1
        );

        vm.warp(block.timestamp + _slowAccumWaitTime);

        (bool isConfirmed, uint256 packetArrivedAt, bytes32 root) = cc
            .notary__
            .getPacketDetails(_accum, _remoteChainId, _packetId);

        // status confirmed
        assertTrue(isConfirmed);

        assertEq(packetArrivedAt, block.timestamp - _slowAccumWaitTime);
        assertEq(root, _root);

        assertEq(
            cc.notary__.getRemoteRoot(_remoteChainId, _accum, _packetId),
            _root
        );

        // status confirmed
        assertEq(
            uint256(
                cc.notary__.getPacketStatus(_accum, _remoteChainId, _packetId)
            ),
            3
        );

        hoax(_raju);
        vm.expectRevert(INotary.AlreadyProposed.selector);
        cc.notary__.propose(
            _remoteChainId,
            _accum,
            _packetId,
            _root,
            _getSignature(digest, _attesterPrivateKey)
        );
    }

    function testProposeWithoutRole() external {
        bytes32 digest = keccak256(
            abi.encode(_remoteChainId, _accum, _packetId, _root)
        );

        hoax(_socketOwner);
        cc.notary__.grantAttesterRole(_remoteChainId, _attester);

        hoax(_raju);
        cc.notary__.propose(
            _remoteChainId,
            _accum,
            _packetId,
            _root,
            _getSignature(digest, _attesterPrivateKey)
        );
    }

    function testPausePacketOnDest() external {
        hoax(_socketOwner);
        cc.notary__.addAccumulator(_accum, _remoteChainId, false);
        hoax(_socketOwner);
        cc.notary__.grantAttesterRole(_remoteChainId, _attester);

        hoax(_socketOwner);
        vm.expectRevert(INotary.RootNotFound.selector);
        cc.notary__.pausePacketOnDest(_accum, _remoteChainId, _packetId, _root);

        bytes32 digest = keccak256(
            abi.encode(_remoteChainId, _accum, _packetId, _root)
        );

        hoax(_raju);
        cc.notary__.propose(
            _remoteChainId,
            _accum,
            _packetId,
            _root,
            _getSignature(digest, _attesterPrivateKey)
        );

        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        cc.notary__.pausePacketOnDest(_accum, _remoteChainId, _packetId, _root);

        hoax(_socketOwner);
        cc.notary__.pausePacketOnDest(_accum, _remoteChainId, _packetId, _root);

        assertEq(
            uint256(
                cc.notary__.getPacketStatus(_accum, _remoteChainId, _packetId)
            ),
            2
        );

        hoax(_socketOwner);
        vm.expectRevert(INotary.PacketPaused.selector);
        cc.notary__.pausePacketOnDest(_accum, _remoteChainId, _packetId, _root);
    }

    function testAcceptPausedPacket() external {
        hoax(_socketOwner);
        cc.notary__.addAccumulator(_accum, _remoteChainId, false);
        hoax(_socketOwner);
        cc.notary__.grantAttesterRole(_remoteChainId, _attester);

        bytes32 digest = keccak256(
            abi.encode(_remoteChainId, _accum, _packetId, _root)
        );

        hoax(_raju);
        cc.notary__.propose(
            _remoteChainId,
            _accum,
            _packetId,
            _root,
            _getSignature(digest, _attesterPrivateKey)
        );

        hoax(_socketOwner);
        vm.expectRevert(INotary.PacketNotPaused.selector);
        cc.notary__.acceptPausedPacket(_accum, _remoteChainId, _packetId);

        hoax(_socketOwner);
        cc.notary__.pausePacketOnDest(_accum, _remoteChainId, _packetId, _root);

        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        cc.notary__.acceptPausedPacket(_accum, _remoteChainId, _packetId);

        hoax(_socketOwner);
        cc.notary__.acceptPausedPacket(_accum, _remoteChainId, _packetId);

        vm.warp(block.timestamp + _slowAccumWaitTime);

        assertEq(
            uint256(
                cc.notary__.getPacketStatus(_accum, _remoteChainId, _packetId)
            ),
            3
        );
    }

    function _getSignature(bytes32 digest, uint256 privateKey_)
        internal
        returns (bytes memory sig)
    {
        digest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", digest)
        );
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

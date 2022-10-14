// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Setup.t.sol";

contract AdminNotaryTest is Setup {
    address constant _accum = address(4);
    bytes32 constant _root = bytes32(uint256(5));
    uint256 constant _packetId = uint256(6);

    bytes32 constant _altRoot = bytes32(uint256(8));
    uint256 _chainSlug = 0x2013AA263;
    uint256 _remoteChainSlug = 0x2013AA264;

    struct SignatureParams {
        uint256 localChainSlug;
        uint256 remoteChainSlug;
        address accum;
        uint256 packetId;
        bytes32 root;
        uint256 privateKey;
    }

    SignatureParams sp;
    SignatureParams remoteSp;

    ChainContext cc;

    function setUp() external {
        uint256[] memory attesters = new uint256[](2);
        attesters[0] = _attesterPrivateKey;
        attesters[1] = _altAttesterPrivateKey;

        _attester = vm.addr(_attesterPrivateKey);
        _altAttester = vm.addr(_altAttesterPrivateKey);

        (cc.sigVerifier__, cc.notary__) = _deployNotary(
            _chainSlug,
            _socketOwner
        );

        sp = SignatureParams(
            _chainSlug,
            _remoteChainSlug,
            _accum,
            _packetId,
            _root,
            _attesterPrivateKey
        );

        remoteSp = SignatureParams(
            _remoteChainSlug,
            _chainSlug,
            _accum,
            _packetId,
            _root,
            _attesterPrivateKey
        );
    }

    function testDeployment() external {
        assertEq(cc.notary__.owner(), _socketOwner);
        assertEq(cc.notary__.chainSlug(), _chainSlug);
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
        cc.notary__.grantAttesterRole(_remoteChainSlug, _attester);

        assertTrue(cc.notary__.hasRole(bytes32(_remoteChainSlug), _attester));

        vm.expectRevert(INotary.AttesterExists.selector);
        cc.notary__.grantAttesterRole(_remoteChainSlug, _attester);

        assertEq(cc.notary__.totalAttestors(_remoteChainSlug), 1);
    }

    function testRevokeAttesterRole() external {
        vm.startPrank(_socketOwner);
        vm.expectRevert(INotary.AttesterNotFound.selector);
        cc.notary__.revokeAttesterRole(_remoteChainSlug, _attester);

        cc.notary__.grantAttesterRole(_remoteChainSlug, _attester);
        cc.notary__.revokeAttesterRole(_remoteChainSlug, _attester);

        assertFalse(cc.notary__.hasRole(bytes32(_remoteChainSlug), _attester));
        assertEq(cc.notary__.totalAttestors(_remoteChainSlug), 0);
    }

    function testSeal() external {
        hoax(_socketOwner);
        cc.notary__.grantAttesterRole(_remoteChainSlug, _attester);

        // wrong packet sealed
        vm.mockCall(
            _accum,
            abi.encodeWithSelector(IAccumulator.sealPacket.selector),
            abi.encode(_altRoot, _packetId, _remoteChainSlug)
        );

        hoax(_attester);
        vm.expectRevert(INotary.InvalidAttester.selector);
        cc.notary__.seal(_accum, _getSignature(sp));

        // correct packet sealed
        vm.mockCall(
            _accum,
            abi.encodeWithSelector(IAccumulator.sealPacket.selector),
            abi.encode(_root, _packetId, _remoteChainSlug)
        );
        hoax(_attester);
        cc.notary__.seal(_accum, _getSignature(sp));

        bytes memory altSign = _getSignature(
            SignatureParams(
                _chainSlug,
                _remoteChainSlug,
                _accum,
                _packetId,
                _root,
                _altAttesterPrivateKey
            )
        );

        // invalid attester
        hoax(_attester);
        vm.expectRevert(INotary.InvalidAttester.selector);
        cc.notary__.seal(_accum, altSign);
    }

    function testChallengeSignature() external {
        hoax(_socketOwner);
        cc.notary__.grantAttesterRole(_remoteChainSlug, _attester);

        bytes memory altSign = _getSignature(
            SignatureParams(
                _chainSlug,
                _remoteChainSlug,
                _accum,
                _packetId,
                _altRoot,
                _attesterPrivateKey
            )
        );

        // TODO: check if event is not emitted
        // if the roots is bytes32(0), the event will not be emitted
        hoax(_raju);
        vm.expectRevert();
        cc.notary__.challengeSignature(
            _root,
            _packetId,
            _remoteChainSlug,
            _accum,
            altSign
        );

        vm.mockCall(
            _accum,
            abi.encodeWithSelector(IAccumulator.sealPacket.selector),
            abi.encode(_root, _packetId, _remoteChainSlug)
        );

        hoax(_attester);
        cc.notary__.seal(_accum, _getSignature(sp));

        // if the roots don't match, the event will not be emitted
        hoax(_raju);
        cc.notary__.challengeSignature(
            _altRoot,
            _packetId,
            _remoteChainSlug,
            _accum,
            altSign
        );
    }

    function testPropose() external {
        hoax(_socketOwner);
        cc.notary__.grantAttesterRole(_remoteChainSlug, _attester);

        hoax(_raju);
        cc.notary__.propose(
            _remoteChainSlug,
            _accum,
            _packetId,
            _root,
            _getSignature(remoteSp)
        );

        assertEq(
            cc.notary__.getRemoteRoot(_remoteChainSlug, _accum, _packetId),
            _root
        );

        assertEq(
            cc.notary__.getConfirmations(_accum, _remoteChainSlug, _packetId),
            1
        );

        (
            INotary.PacketStatus status,
            uint256 packetArrivedAt,
            ,
            bytes32 root
        ) = cc.notary__.getPacketDetails(_accum, _remoteChainSlug, _packetId);

        // status proposed
        assertEq(uint256(status), 1);
        assertEq(root, _root);
        assertEq(packetArrivedAt, block.timestamp);

        assertEq(
            cc.notary__.getRemoteRoot(_remoteChainSlug, _accum, _packetId),
            _root
        );

        hoax(_raju);
        vm.expectRevert(INotary.AlreadyProposed.selector);
        cc.notary__.propose(
            _remoteChainSlug,
            _accum,
            _packetId,
            _root,
            _getSignature(sp)
        );
    }

    function testProposeWithoutRole() external {
        hoax(_raju);
        vm.expectRevert(INotary.InvalidAttester.selector);
        cc.notary__.propose(
            _remoteChainSlug,
            _accum,
            _packetId,
            _root,
            _getSignature(remoteSp)
        );
    }

    function testConfirmRoot() external {
        hoax(_socketOwner);
        cc.notary__.grantAttesterRole(_remoteChainSlug, _attester);
        hoax(_socketOwner);
        cc.notary__.grantAttesterRole(_remoteChainSlug, _altAttester);

        // status not-proposed
        assertEq(
            uint256(
                cc.notary__.getPacketStatus(_accum, _remoteChainSlug, _packetId)
            ),
            0
        );

        hoax(_socketOwner);
        vm.expectRevert(INotary.RootNotFound.selector);
        cc.notary__.confirmRoot(
            _remoteChainSlug,
            _accum,
            _packetId,
            _root,
            _getSignature(remoteSp)
        );

        hoax(_raju);
        cc.notary__.propose(
            _remoteChainSlug,
            _accum,
            _packetId,
            _root,
            _getSignature(remoteSp)
        );

        // status proposed
        assertEq(
            uint256(
                cc.notary__.getPacketStatus(_accum, _remoteChainSlug, _packetId)
            ),
            1
        );

        (, , uint256 pendingAttestations, ) = cc.notary__.getPacketDetails(
            _accum,
            _remoteChainSlug,
            _packetId
        );

        // one pending attestations
        assertEq(pendingAttestations, 1);

        hoax(_raju);
        vm.expectRevert(INotary.AlreadyAttested.selector);
        cc.notary__.confirmRoot(
            _remoteChainSlug,
            _accum,
            _packetId,
            _root,
            _getSignature(remoteSp)
        );

        bytes memory altSign = _getSignature(
            SignatureParams(
                _remoteChainSlug,
                _chainSlug,
                _accum,
                _packetId,
                _root,
                _altAttesterPrivateKey
            )
        );

        hoax(_socketOwner);
        cc.notary__.pausePacketOnRemote(
            _accum,
            _remoteChainSlug,
            _packetId,
            _root
        );

        hoax(_raju);
        vm.expectRevert(INotary.PacketPaused.selector);
        cc.notary__.confirmRoot(
            _remoteChainSlug,
            _accum,
            _packetId,
            _root,
            altSign
        );

        hoax(_socketOwner);
        cc.notary__.acceptPausedPacket(_accum, _remoteChainSlug, _packetId);
        hoax(_raju);
        cc.notary__.confirmRoot(
            _remoteChainSlug,
            _accum,
            _packetId,
            _root,
            altSign
        );

        (, , pendingAttestations, ) = cc.notary__.getPacketDetails(
            _accum,
            _remoteChainSlug,
            _packetId
        );

        // no pending attestations
        assertEq(pendingAttestations, 0);
    }

    function testPausePacketOnRemote() external {
        hoax(_socketOwner);
        cc.notary__.grantAttesterRole(_remoteChainSlug, _attester);

        hoax(_socketOwner);
        vm.expectRevert(INotary.RootNotFound.selector);
        cc.notary__.pausePacketOnRemote(
            _accum,
            _remoteChainSlug,
            _packetId,
            _root
        );

        hoax(_raju);
        cc.notary__.propose(
            _remoteChainSlug,
            _accum,
            _packetId,
            _root,
            _getSignature(remoteSp)
        );

        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        cc.notary__.pausePacketOnRemote(
            _accum,
            _remoteChainSlug,
            _packetId,
            _root
        );

        hoax(_socketOwner);
        cc.notary__.pausePacketOnRemote(
            _accum,
            _remoteChainSlug,
            _packetId,
            _root
        );

        assertEq(
            uint256(
                cc.notary__.getPacketStatus(_accum, _remoteChainSlug, _packetId)
            ),
            2
        );

        hoax(_socketOwner);
        vm.expectRevert(INotary.PacketPaused.selector);
        cc.notary__.pausePacketOnRemote(
            _accum,
            _remoteChainSlug,
            _packetId,
            _root
        );
    }

    function testAcceptPausedPacket() external {
        hoax(_socketOwner);
        cc.notary__.grantAttesterRole(_remoteChainSlug, _attester);

        hoax(_raju);
        cc.notary__.propose(
            _remoteChainSlug,
            _accum,
            _packetId,
            _root,
            _getSignature(remoteSp)
        );

        hoax(_socketOwner);
        vm.expectRevert(INotary.PacketNotPaused.selector);
        cc.notary__.acceptPausedPacket(_accum, _remoteChainSlug, _packetId);

        hoax(_socketOwner);
        cc.notary__.pausePacketOnRemote(
            _accum,
            _remoteChainSlug,
            _packetId,
            _root
        );

        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        cc.notary__.acceptPausedPacket(_accum, _remoteChainSlug, _packetId);

        hoax(_socketOwner);
        cc.notary__.acceptPausedPacket(_accum, _remoteChainSlug, _packetId);

        vm.warp(block.timestamp + _slowAccumWaitTime);

        assertEq(
            uint256(
                cc.notary__.getPacketStatus(_accum, _remoteChainSlug, _packetId)
            ),
            1
        );
    }

    function _getSignature(SignatureParams memory sp_)
        internal
        returns (bytes memory sig)
    {
        bytes32 digest = keccak256(
            abi.encode(
                sp_.localChainSlug,
                sp_.remoteChainSlug,
                sp_.accum,
                sp_.packetId,
                sp_.root
            )
        );
        digest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", digest)
        );

        (uint8 sigV, bytes32 sigR, bytes32 sigS) = vm.sign(
            sp_.privateKey,
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
}

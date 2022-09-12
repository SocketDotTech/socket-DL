// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Setup.sol";

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
        vm.startPrank(_socketOwner);
        // should add accumulator
        cc.notary__.addAccumulator(_accum, _remoteChainId, true);
    }

    function testConfirmRootSlowPath() external {
        hoax(_socketOwner);
        cc.notary__.addAccumulator(_accum, _remoteChainId, false);
        hoax(_socketOwner);
        cc.notary__.grantAttesterRole(_remoteChainId, _attester);
        hoax(_socketOwner);
        cc.notary__.grantAttesterRole(_remoteChainId, _altAttester);

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

    function testVerifyAndSeal() external {
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
        cc.notary__.verifyAndSeal(
            _accum,
            _remoteChainId,
            _getSignature(digest, _attesterPrivateKey)
        );

        hoax(_attester);
        vm.expectRevert(INotary.InvalidAttester.selector);
        cc.notary__.verifyAndSeal(
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
        cc.notary__.verifyAndSeal(
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

    function testSubmitRemoteRoot() external {
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

    function testSubmitRemoteRootWithoutRole() external {
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

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Setup.t.sol";

contract AdminNotaryTest is Setup {
    address constant _accum = address(4);
    bytes32 constant _root = bytes32(uint256(5));
    uint256 constant _id = uint256(6);

    bytes32 constant _altRoot = bytes32(uint256(8));
    uint256 _chainSlug = 1;
    uint256 _remoteChainSlug = 2;

    uint256 private _localPacketId;
    uint256 private _remotePacketId;
    bytes private localSig;
    bytes private remoteSig;

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

        _localPacketId = _getPackedId(_accum, _chainSlug, _id);
        localSig = _createSignature(
            _remoteChainSlug,
            _localPacketId,
            _attesterPrivateKey,
            _root
        );

        _remotePacketId = _getPackedId(_accum, _remoteChainSlug, _id);
        remoteSig = _createSignature(
            _chainSlug,
            _remotePacketId,
            _attesterPrivateKey,
            _root
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
            abi.encode(_altRoot, _id, _remoteChainSlug)
        );

        hoax(_attester);
        vm.expectRevert(INotary.InvalidAttester.selector);
        cc.notary__.seal(_accum, localSig);

        // correct packet sealed
        vm.mockCall(
            _accum,
            abi.encodeWithSelector(IAccumulator.sealPacket.selector),
            abi.encode(_root, _id, _remoteChainSlug)
        );
        hoax(_attester);
        cc.notary__.seal(_accum, localSig);

        bytes memory altSign = _createSignature(
            _remoteChainSlug,
            _localPacketId,
            _altAttesterPrivateKey,
            _root
        );

        // invalid attester
        hoax(_attester);
        vm.expectRevert(INotary.InvalidAttester.selector);
        cc.notary__.seal(_accum, altSign);
    }

    function testAttest() external {
        hoax(_socketOwner);
        cc.notary__.grantAttesterRole(_remoteChainSlug, _attester);
        hoax(_socketOwner);
        cc.notary__.grantAttesterRole(_remoteChainSlug, _altAttester);

        hoax(_raju);
        cc.notary__.attest(_remotePacketId, _root, remoteSig);

        assertEq(cc.notary__.getRemoteRoot(_remotePacketId), _root);
        assertEq(cc.notary__.getAttestationCount(_remotePacketId), 1);

        (
            INotary.PacketStatus status,
            uint256 packetArrivedAt,
            ,
            bytes32 root
        ) = cc.notary__.getPacketDetails(_remotePacketId);

        // status proposed
        assertEq(uint256(status), 1);
        assertEq(root, _root);
        assertEq(packetArrivedAt, block.timestamp);

        assertEq(cc.notary__.getRemoteRoot(_remotePacketId), _root);

        hoax(_raju);
        vm.expectRevert(INotary.AlreadyAttested.selector);
        cc.notary__.attest(_remotePacketId, _root, remoteSig);

        // one pending attestations
        (, , uint256 pendingAttestations, ) = cc.notary__.getPacketDetails(
            _remotePacketId
        );
        assertEq(pendingAttestations, 1);

        bytes memory altSign = _createSignature(
            _chainSlug,
            _remotePacketId,
            _altAttesterPrivateKey,
            _root
        );

        hoax(_raju);
        cc.notary__.attest(_remotePacketId, _root, altSign);

        (, , pendingAttestations, ) = cc.notary__.getPacketDetails(
            _remotePacketId
        );

        // no pending attestations
        assertEq(pendingAttestations, 0);
    }

    function testAttestWithoutRole() external {
        hoax(_raju);
        vm.expectRevert(INotary.InvalidAttester.selector);
        cc.notary__.attest(_localPacketId, _root, localSig);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Notary/AdminNotary.sol";
import "../src/interfaces/IAccumulator.sol";

contract AdminNotaryTest is Test {
    address constant _owner = address(1);
    uint256 constant _attesterPrivateKey = uint256(2);
    address constant _accum = address(3);
    bytes32 constant _root = bytes32(uint256(4));
    uint256 constant _packetId = uint256(5);
    address _attester;
    address constant _raju = address(6);
    bytes32 constant _altRoot = bytes32(uint256(7));

    uint256 constant _chainId = 0x2013AA263;
    uint256 constant _remoteChainId = 0x2013AA264;
    bool constant _isFast = false;

    Notary _notary;

    function setUp() external {
        _attester = vm.addr(_attesterPrivateKey);
        hoax(_owner);
        _notary = new Notary(_chainId);
    }

    function testDeployment() external {
        assertEq(_notary.owner(), _owner);
        assertEq(_notary.chainId(), _chainId);
    }

    function testAddBond() external {
        uint256 amount = 100e18;
        hoax(_attester);
        vm.expectRevert(Notary.Restricted.selector);
        _notary.addBond{value: amount}();
    }

    function testReduceAmount() external {
        uint256 reduceAmount = 10e18;
        hoax(_attester);
        vm.expectRevert(Notary.Restricted.selector);
        _notary.reduceBond(reduceAmount);
    }

    function testUnbondattester() external {
        hoax(_attester);
        vm.expectRevert(Notary.Restricted.selector);
        _notary.unbondAttester();
    }

    function testClaimBond() external {
        hoax(_attester);
        vm.expectRevert(Notary.Restricted.selector);
        _notary.claimBond();
    }

    function testSubmitSignature() external {
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
        (uint8 sigV, bytes32 sigR, bytes32 sigS) = vm.sign(
            _attesterPrivateKey,
            digest
        );

        hoax(_attester);
        _notary.submitSignature(sigV, sigR, sigS, _accum);
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
        (uint8 sigV, bytes32 sigR, bytes32 sigS) = vm.sign(
            _attesterPrivateKey,
            digest
        );

        hoax(_attester);
        _notary.submitSignature(sigV, sigR, sigS, _accum);

        bytes32 altDigest = keccak256(
            abi.encode(_chainId, _accum, _packetId, _altRoot)
        );
        (uint8 altSigV, bytes32 altSigR, bytes32 altSigS) = vm.sign(
            _attesterPrivateKey,
            altDigest
        );

        hoax(_raju);
        _notary.challengeSignature(
            altSigV,
            altSigR,
            altSigS,
            _accum,
            _altRoot,
            _packetId
        );
    }

    function testSubmitRemoteRoot() external {
        bytes32 digest = keccak256(
            abi.encode(_remoteChainId, _accum, _packetId, _root)
        );
        (uint8 sigV, bytes32 sigR, bytes32 sigS) = vm.sign(
            _attesterPrivateKey,
            digest
        );

        hoax(_owner);
        _notary.grantAttesterRole(_remoteChainId, _attester);

        hoax(_raju);
        _notary.submitRemoteRoot(
            sigV,
            sigR,
            sigS,
            _remoteChainId,
            _accum,
            _packetId,
            _root
        );

        assertEq(
            _notary.getRemoteRoot(_remoteChainId, _accum, _packetId),
            _root
        );
    }

    function testSubmitRemoteRootWithoutRole() external {
        bytes32 digest = keccak256(
            abi.encode(_remoteChainId, _accum, _packetId, _root)
        );
        (uint8 sigV, bytes32 sigR, bytes32 sigS) = vm.sign(
            _attesterPrivateKey,
            digest
        );

        hoax(_raju);
        vm.expectRevert(INotary.InvalidAttester.selector);
        _notary.submitRemoteRoot(
            sigV,
            sigR,
            sigS,
            _remoteChainId,
            _accum,
            _packetId,
            _root
        );
    }
}

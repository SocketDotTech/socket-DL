// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Notary/AdminNotary.sol";
import "../src/interfaces/IAccumulator.sol";
import "../src/utils/SignatureVerifier.sol";

contract SocketTest is Test {
    address constant _owner = address(1);
    uint256 constant _signerPrivateKey = uint256(2);
    address constant _accum = address(3);
    bytes32 constant _root = bytes32(uint256(4));
    uint256 constant _packetId = uint256(5);
    address _signer;
    address constant _raju = address(6);
    bytes32 constant _altRoot = bytes32(uint256(7));

    uint256 constant _chainId = 0x2013AA263;
    uint256 constant _remoteChainId = 0x2013AA264;
    bytes32 constant ATTESTER_ROLE = keccak256("ATTESTER_ROLE");

    Notary _notary;
    SignatureVerifier _sigVerifier;

    function setUp() external {
        _signer = vm.addr(_signerPrivateKey);
        _sigVerifier = new SignatureVerifier();

        hoax(_owner);
        _notary = new Notary(_chainId, address(_sigVerifier));
    }

    function testDeployment() external {
        assertEq(_notary.owner(), _owner);
        assertEq(_notary.chainId(), _chainId);
    }

    function testAddBond() external {
        uint256 amount = 100e18;
        hoax(_signer);
        vm.expectRevert(Notary.Restricted.selector);
        _notary.addBond{value: amount}();
    }

    function testReduceAmount() external {
        uint256 reduceAmount = 10e18;
        hoax(_signer);
        vm.expectRevert(Notary.Restricted.selector);
        _notary.reduceBond(reduceAmount);
    }

    function testUnbondSigner() external {
        hoax(_signer);
        vm.expectRevert(Notary.Restricted.selector);
        _notary.unbondSigner();
    }

    function testClaimBond() external {
        hoax(_signer);
        vm.expectRevert(Notary.Restricted.selector);
        _notary.claimBond();
    }

    function testSubmitSignature() external {
        hoax(_owner);
        _notary.grantRole(ATTESTER_ROLE, _signer);

        vm.mockCall(
            _accum,
            abi.encodeWithSelector(IAccumulator.sealPacket.selector),
            abi.encode(_root, _packetId)
        );

        bytes32 digest = keccak256(
            abi.encode(_chainId, _accum, _packetId, _root)
        );

        hoax(_signer);
        _notary.submitSignature(_accum, _getSignature(digest));
    }

    function testChallengeSignature() external {
        hoax(_owner);
        _notary.grantRole(ATTESTER_ROLE, _signer);

        vm.mockCall(
            _accum,
            abi.encodeWithSelector(IAccumulator.sealPacket.selector),
            abi.encode(_root, _packetId)
        );

        bytes32 digest = keccak256(
            abi.encode(_chainId, _accum, _packetId, _root)
        );

        hoax(_signer);
        _notary.submitSignature(_accum, _getSignature(digest));

        bytes32 altDigest = keccak256(
            abi.encode(_chainId, _accum, _packetId, _altRoot)
        );

        hoax(_raju);
        _notary.challengeSignature(
            _accum,
            _altRoot,
            _packetId,
            _getSignature(altDigest)
        );
    }

    function testSubmitRemoteRoot() external {
        bytes32 digest = keccak256(
            abi.encode(_remoteChainId, _accum, _packetId, _root)
        );
        hoax(_owner);
        _notary.grantSignerRole(_remoteChainId, _signer);

        hoax(_raju);
        _notary.submitRemoteRoot(
            _remoteChainId,
            _accum,
            _packetId,
            _root,
            _getSignature(digest)
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

        hoax(_raju);
        vm.expectRevert(INotary.InvalidSigner.selector);
        _notary.submitRemoteRoot(
            _remoteChainId,
            _accum,
            _packetId,
            _root,
            _getSignature(digest)
        );
    }

    function _getSignature(bytes32 digest) internal returns (bytes memory sig) {
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
}

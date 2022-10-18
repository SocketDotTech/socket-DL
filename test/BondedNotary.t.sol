// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/notaries/BondedNotary.sol";
import "../src/interfaces/IAccumulator.sol";
import "../src/utils/SignatureVerifier.sol";

// contract BondedNotaryTest is Test {
//     address constant _owner = address(1);
//     uint256 constant _attesterPrivateKey = uint256(2);
//     address constant _accum = address(3);
//     bytes32 constant _root = bytes32(uint256(4));
//     uint256 constant _packetId = uint256(5);
//     address _attester;
//     address constant _raju = address(6);
//     bytes32 constant _altRoot = bytes32(uint256(7));

//     uint256 constant _minBondAmount = 100e18;
//     uint256 constant _bondClaimDelay = 1 weeks;
//     uint256 constant _chainSlug = 0x2013AA263;
//     uint256 constant _remoteChainSlug = 0x2013AA264;

//     BondedNotary _notary;
//     SignatureVerifier _sigVerifier;

//     function setUp() external {
//         _attester = vm.addr(_attesterPrivateKey);
//         _sigVerifier = new SignatureVerifier();

//         hoax(_owner);
//         _notary = new BondedNotary(
//             _minBondAmount,
//             _bondClaimDelay,
//             _chainSlug,
//             address(_sigVerifier)
//         );
//     }

//     function testDeployment() external {
//         assertEq(_notary.owner(), _owner);
//         assertEq(_notary.minBondAmount(), _minBondAmount);
//         assertEq(_notary.bondClaimDelay(), _bondClaimDelay);
//         assertEq(_notary.chainSlug(), _chainSlug);
//     }

//     function testAddBond() external {
//         uint256 amount = 100e18;
//         hoax(_attester);
//         _notary.addBond{value: amount}();
//         assertEq(_notary.getBond(_attester), amount);
//     }

//     function testReduceValidAmount() external {
//         uint256 initialAmount = 150e18;
//         uint256 reduceAmount = 10e18;

//         assertGe(initialAmount - reduceAmount, _minBondAmount);

//         startHoax(_attester, initialAmount);
//         _notary.addBond{value: initialAmount}();
//         _notary.reduceBond(reduceAmount);

//         assertEq(_notary.getBond(_attester), initialAmount - reduceAmount);
//         assertEq(_attester.balance, reduceAmount);
//     }

//     function testReduceInvalidAmount() external {
//         uint256 initialAmount = 150e18;
//         uint256 reduceAmount = 90e18;

//         assertLt(initialAmount - reduceAmount, _minBondAmount);

//         startHoax(_attester, initialAmount);
//         _notary.addBond{value: initialAmount}();
//         vm.expectRevert(INotary.InvalidBondReduce.selector);
//         _notary.reduceBond(reduceAmount);
//     }

//     function testUnbondAttester() external {
//         uint256 amount = 150e18;
//         uint256 claimTime = block.timestamp + _bondClaimDelay;

//         startHoax(_attester, amount);
//         _notary.addBond{value: amount}();
//         _notary.unbondAttester();

//         assertEq(_notary.getBond(_attester), 0);
//         (uint256 unbondAmount, uint256 unbondClaimTime) = _notary.getUnbondData(
//             _attester
//         );
//         assertEq(unbondAmount, amount);
//         assertEq(unbondClaimTime, claimTime);
//     }

//     function testClaimBondBeforeDelay() external {
//         uint256 amount = 150e18;
//         uint256 claimTime = block.timestamp + _bondClaimDelay;

//         startHoax(_attester, amount);
//         _notary.addBond{value: amount}();
//         _notary.unbondAttester();

//         vm.warp(claimTime - 10);
//         vm.expectRevert(INotary.ClaimTimeLeft.selector);
//         _notary.claimBond();

//         assertEq(_notary.getBond(_attester), 0);
//         (uint256 unbondAmount, uint256 unbondClaimTime) = _notary.getUnbondData(
//             _attester
//         );
//         assertEq(unbondAmount, amount);
//         assertEq(unbondClaimTime, claimTime);
//         assertEq(_attester.balance, 0);
//     }

//     function testClaimBondAfterDelay() external {
//         uint256 amount = 150e18;
//         uint256 claimTime = block.timestamp + _bondClaimDelay;

//         startHoax(_attester, amount);
//         _notary.addBond{value: amount}();
//         _notary.unbondAttester();

//         vm.warp(claimTime + 10);
//         _notary.claimBond();

//         assertEq(_notary.getBond(_attester), 0);
//         (uint256 unbondAmount, uint256 unbondClaimTime) = _notary.getUnbondData(
//             _attester
//         );
//         assertEq(unbondAmount, 0);
//         assertEq(unbondClaimTime, 0);
//         assertEq(_attester.balance, amount);
//     }

//     function testSeal() external {
//         startHoax(_attester);
//         _notary.addBond{value: _minBondAmount}();

//         vm.mockCall(
//             _accum,
//             abi.encodeWithSelector(IAccumulator.sealPacket.selector),
//             abi.encode(_root, _packetId)
//         );

//         bytes32 digest = keccak256(
//             abi.encode(_chainSlug, _accum, _packetId, _root)
//         );

//         _notary.seal(_accum, _getSignature(digest));
//     }

//     function testSealWithoutEnoughBond() external {
//         startHoax(_attester);
//         _notary.addBond{value: _minBondAmount / 2}();

//         vm.mockCall(
//             _accum,
//             abi.encodeWithSelector(IAccumulator.sealPacket.selector),
//             abi.encode(_root, _packetId)
//         );

//         bytes32 digest = keccak256(
//             abi.encode(_chainSlug, _accum, _packetId, _root)
//         );

//         vm.expectRevert(INotary.InvalidBond.selector);
//         _notary.seal(_accum, _getSignature(digest));
//     }

//     function testChallengeSignature() external {
//         hoax(_attester, 150e18);
//         _notary.addBond{value: 120e18}();

//         vm.mockCall(
//             _accum,
//             abi.encodeWithSelector(IAccumulator.sealPacket.selector),
//             abi.encode(_root, _packetId)
//         );

//         bytes32 digest = keccak256(
//             abi.encode(_chainSlug, _accum, _packetId, _root)
//         );

//         _notary.seal(_accum, _getSignature(digest));

//         bytes32 altDigest = keccak256(
//             abi.encode(_chainSlug, _accum, _packetId, _altRoot)
//         );

//         hoax(_raju, 0);
//         _notary.challengeSignature(
//             _accum,
//             _altRoot,
//             _packetId,
//             _getSignature(altDigest)
//         );

//         assertEq(_attester.balance, 30e18);
//         assertEq(_raju.balance, 120e18);
//         assertEq(address(_notary).balance, 0);
//     }

//     function testSubmitRemoteRoot() external {
//         bytes32 digest = keccak256(
//             abi.encode(_remoteChainSlug, _accum, _packetId, _root)
//         );

//         hoax(_owner);
//         _notary.grantAttesterRole(_remoteChainSlug, _attester);

//         hoax(_raju);
//         _notary.propose(
//             _remoteChainSlug,
//             _accum,
//             _packetId,
//             _root,
//             _getSignature(digest)
//         );

//         assertEq(
//             _notary.getRemoteRoot(_remoteChainSlug, _accum, _packetId),
//             _root
//         );
//     }

//     function testSubmitRemoteRootWithoutRole() external {
//         bytes32 digest = keccak256(
//             abi.encode(_remoteChainSlug, _accum, _packetId, _root)
//         );

//         hoax(_raju);
//         vm.expectRevert(INotary.InvalidAttester.selector);
//         _notary.propose(
//             _remoteChainSlug,
//             _accum,
//             _packetId,
//             _root,
//             _getSignature(digest)
//         );
//     }

//     function _getSignature(bytes32 digest) internal returns (bytes memory sig) {
//         (uint8 sigV, bytes32 sigR, bytes32 sigS) = vm.sign(
//             _attesterPrivateKey,
//             digest
//         );

//         sig = new bytes(65);
//         bytes1 v32 = bytes1(sigV);

//         assembly {
//             mstore(add(sig, 96), v32)
//             mstore(add(sig, 32), sigR)
//             mstore(add(sig, 64), sigS)
//         }
//     }
// }

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./Setup.t.sol";

contract VerifierTest is Setup {
    address _notAPauser = address(10);

    uint256 chainId = 1;
    uint256 destChainId = 2;
    uint256 anotherDestChainId = 3;

    uint256 timeoutInSeconds = 100;

    Verifier verifier;
    ChainContext cc;

    function setUp() public {
        cc.chainId = chainId;
        (cc.sigVerifier__, cc.notary__) = _deployNotary(chainId, _socketOwner);

        hoax(_socketOwner);
        cc.verifier__ = new Verifier(
            _plugOwner,
            address(cc.notary__),
            timeoutInSeconds
        );

        _initVerifier(cc, destChainId);
    }

    function testDeployment() public {
        assertEq(cc.verifier__.manager(), _plugOwner);
        assertEq(address(cc.verifier__.notary()), address(cc.notary__));
        assertEq(cc.verifier__.timeoutInSeconds(), timeoutInSeconds);

        bool isActive = cc.verifier__.isChainActive(destChainId);
        assertTrue(isActive);
    }

    function testPausing() public {
        hoax(_notAPauser);
        vm.expectRevert(IVerifier.OnlyPauser.selector);
        cc.verifier__.pause(destChainId);

        bool isPauser = cc.verifier__.isPauser(_pauser, destChainId);
        assertTrue(isPauser);

        hoax(_pauser);
        cc.verifier__.pause(destChainId);

        assertFalse(cc.verifier__.isChainActive(destChainId));
    }

    function testActivate() public {
        hoax(_pauser);
        cc.verifier__.pause(destChainId);

        hoax(_notAPauser);
        vm.expectRevert(IVerifier.OnlyPauser.selector);
        cc.verifier__.activate(destChainId);

        hoax(_pauser);
        cc.verifier__.activate(destChainId);

        assertTrue(cc.verifier__.isChainActive(destChainId));
    }

    function testAddPauser() external {
        hoax(_notAPauser);
        vm.expectRevert(IVerifier.OnlyManager.selector);
        cc.verifier__.addPauser(_pauser, anotherDestChainId);

        vm.startPrank(_plugOwner);
        vm.expectRevert(IVerifier.PauserAlreadySet.selector);
        cc.verifier__.addPauser(_pauser, destChainId);

        cc.verifier__.addPauser(_pauser, anotherDestChainId);

        assertTrue(cc.verifier__.isPauser(_pauser, anotherDestChainId));
    }

    function testRemovePauser() external {
        hoax(_plugOwner);
        vm.expectRevert(IVerifier.NotPauser.selector);
        cc.verifier__.removePauser(_notAPauser, anotherDestChainId);

        hoax(_plugOwner);
        cc.verifier__.addPauser(_notAPauser, anotherDestChainId);

        hoax(_notAPauser);
        vm.expectRevert(IVerifier.OnlyManager.selector);
        cc.verifier__.removePauser(_notAPauser, anotherDestChainId);

        hoax(_plugOwner);
        cc.verifier__.removePauser(_notAPauser, anotherDestChainId);

        assertFalse(cc.verifier__.isPauser(_notAPauser, anotherDestChainId));
    }

    function testVerifyRoot() public {
        bool isPauser = cc.verifier__.isPauser(_pauser, destChainId);
        assertTrue(isPauser);

        vm.mockCall(
            address(cc.notary__),
            abi.encodeWithSelector(INotary.getPacketDetails.selector),
            abi.encode(true, 1, bytes32(0))
        );

        (bool valid, ) = cc.verifier__.verifyRoot(address(0), destChainId, 0);
        assertTrue(valid);

        vm.mockCall(
            address(cc.notary__),
            abi.encodeWithSelector(INotary.getPacketDetails.selector),
            abi.encode(false, 1, bytes32(0))
        );

        (valid, ) = cc.verifier__.verifyRoot(address(0), destChainId, 0);
        assertFalse(valid);

        vm.mockCall(
            address(cc.notary__),
            abi.encodeWithSelector(INotary.getPacketDetails.selector),
            abi.encode(true, block.timestamp, bytes32(0))
        );

        vm.warp(1000);

        (valid, ) = cc.verifier__.verifyRoot(address(0), destChainId, 0);
        assertFalse(valid);

        vm.prank(_pauser);
        cc.verifier__.pause(destChainId);

        (valid, ) = cc.verifier__.verifyRoot(address(0), destChainId, 0);
        assertFalse(valid);
    }
}

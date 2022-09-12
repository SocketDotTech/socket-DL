// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./Setup.sol";

contract VerifierTest is Setup {
    address DUMMY_SOCKET = address(2);
    uint256 chainId = 1;
    uint256 destChainId = 2;

    uint256 timeoutInSeconds = 100;

    Verifier verifier;
    ChainContext cc;

    function setUp() public {
        cc.chainId = chainId;
        (cc.sigVerifier__, cc.notary__) = _deployNotary(chainId, _socketOwner);

        hoax(_socketOwner);
        cc.verifier__ = new Verifier(
            DUMMY_SOCKET,
            _plugOwner,
            address(cc.notary__),
            timeoutInSeconds
        );

        _initVerifier(cc, destChainId);
    }

    function testDeployment() public {
        assertEq(cc.verifier__.manager(), _plugOwner);
        assertEq(cc.verifier__.socket(), DUMMY_SOCKET);
        bool isActive = cc.verifier__.isChainActive(destChainId);
        assertTrue(isActive);
    }

    function testPausing() public {
        bool isPauser = cc.verifier__.isPauser(_pauser, destChainId);
        assertTrue(isPauser);

        vm.mockCall(
            address(cc.notary__),
            abi.encodeWithSelector(INotary.getPacketDetails.selector),
            abi.encode(true, 1, bytes32(0))
        );

        vm.prank(DUMMY_SOCKET);
        (bool valid, ) = cc.verifier__.verifyRoot(address(0), destChainId, 0);
        assertTrue(valid);

        vm.prank(_pauser);
        cc.verifier__.pause(destChainId);

        assertFalse(cc.verifier__.isChainActive(destChainId));
    }

    function testVerifyAfterpause() public {
        bool isPauser = cc.verifier__.isPauser(_pauser, destChainId);
        assertTrue(isPauser);

        vm.mockCall(
            address(cc.notary__),
            abi.encodeWithSelector(INotary.getPacketDetails.selector),
            abi.encode(true, 1, bytes32(0))
        );

        vm.prank(DUMMY_SOCKET);
        (bool valid, ) = cc.verifier__.verifyRoot(address(0), destChainId, 0);
        assertTrue(valid);

        vm.prank(_pauser);
        cc.verifier__.pause(destChainId);

        (valid, ) = cc.verifier__.verifyRoot(address(0), destChainId, 0);
        assertFalse(valid);
    }
}

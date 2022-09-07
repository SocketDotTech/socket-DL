// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/verifiers/Verifier.sol";
import "../src/mocks/MockNotary.sol";

contract VerifierTest is Test {
    address DUMMY_MANAGER = address(1);
    address DUMMY_SOCKET = address(2);
    address DUMMY_PAUSER = address(4);
    uint256 chainId = 1;
    uint256 timeoutInSeconds = 100;

    Verifier verifier;

    function setUp() public {
        MockNotary notary__ = new MockNotary();

        verifier = new Verifier(
            DUMMY_SOCKET,
            DUMMY_MANAGER,
            address(notary__),
            timeoutInSeconds
        );
        prankAndaddPauser(DUMMY_PAUSER, chainId);
        vm.prank(DUMMY_PAUSER);
        verifier.activate(chainId);
    }

    function testDeployment() public {
        assertEq(verifier.manager(), DUMMY_MANAGER);
        assertEq(verifier.socket(), DUMMY_SOCKET);
        bool isActive = verifier.isChainActive(chainId);
        assertTrue(isActive);
    }

    function testPausing() public {
        bool isPauser = verifier.isPauser(DUMMY_PAUSER, chainId);
        assertTrue(isPauser);

        vm.prank(DUMMY_SOCKET);
        (bool valid, ) = verifier.verifyRoot(address(0), chainId, 0);
        assertTrue(valid);

        vm.prank(DUMMY_PAUSER);
        verifier.pause(chainId);

        assertFalse(verifier.isChainActive(chainId));
    }

    function testVerifyAfterpause() public {
        bool isPauser = verifier.isPauser(DUMMY_PAUSER, chainId);
        assertTrue(isPauser);

        vm.prank(DUMMY_SOCKET);
        (bool valid, ) = verifier.verifyRoot(address(0), chainId, 0);
        assertTrue(valid);

        vm.prank(DUMMY_PAUSER);
        verifier.pause(chainId);

        (valid, ) = verifier.verifyRoot(address(0), chainId, 0);
        assertFalse(valid);
    }

    function prankAndaddPauser(address pauser, uint256 chainId_) internal {
        vm.prank(DUMMY_MANAGER);
        verifier.addPauser(pauser, chainId_);
    }
}

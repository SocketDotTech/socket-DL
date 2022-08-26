// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {AcceptWithTimeout} from "../src/verifiers/AcceptWithTimeout.sol";

contract AcceptWithTimeoutTest is Test {
    address DUMMY_MANAGER = address(0x75bbC04fA183dd0ac75857a0400F93f766748f01);
    address DUMMY_SOCKET = address(0x75bbC04fa183dd0aC75857A0400F93f766748f02);
    address DUMMY_PAUSER = address(0x4B1d0d4bae850579BD363e8755C88B3b23E12DBd);
    uint256 chainId = 1;

    AcceptWithTimeout verifier;

    function setUp() public {
        verifier = new AcceptWithTimeout(DUMMY_SOCKET, DUMMY_MANAGER);
        prankAndAddPauser(DUMMY_PAUSER, chainId);
        vm.prank(DUMMY_PAUSER);
        verifier.Activate(chainId);
    }

    function testDeployment() public {
        assertEq(verifier.manager(), DUMMY_MANAGER);
        assertEq(verifier.socket(), DUMMY_SOCKET);
        bool isActive = verifier.isChainActive(chainId);
        assertTrue(isActive);
    }

    function testPausing() public {
        bool isPauser = verifier.IsPauser(DUMMY_PAUSER, chainId);
        assertTrue(isPauser);

        vm.prank(DUMMY_SOCKET);
        bool valid = verifier.verifyRoot(
            address(0),
            chainId,
            address(0),
            0,
            bytes32(0)
        );
        assertTrue(valid);

        vm.prank(DUMMY_PAUSER);
        verifier.Pause(chainId);

        assertFalse(verifier.isChainActive(chainId));
    }

    function testVerifyAfterPause() public {
        bool isPauser = verifier.IsPauser(DUMMY_PAUSER, chainId);
        assertTrue(isPauser);

        vm.prank(DUMMY_SOCKET);
        bool valid = verifier.verifyRoot(
            address(0),
            chainId,
            address(0),
            0,
            bytes32(0)
        );
        assertTrue(valid);

        vm.prank(DUMMY_PAUSER);
        verifier.Pause(chainId);

        valid = verifier.verifyRoot(
            address(0),
            chainId,
            address(0),
            0,
            bytes32(0)
        );
        assertFalse(valid);
    }

    function prankAndAddPauser(address pauser, uint256 chainId_) internal {
        vm.prank(DUMMY_MANAGER);
        verifier.AddPauser(pauser, chainId_);
    }
}

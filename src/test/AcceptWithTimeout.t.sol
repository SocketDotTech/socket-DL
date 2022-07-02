// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import {AcceptWithTimeout} from "../verifiers/AcceptWithTimeout.sol";

contract AcceptWithTimeoutTest is Test{
    address DUMMY_MANAGER = address(0x75bbC04fA183dd0ac75857a0400F93f766748f01); 
    address DUMMY_SOCKET = address(0x75bbC04fa183dd0aC75857A0400F93f766748f02); 
    address DUMMY_PAUSER = address(0x4B1d0d4bae850579BD363e8755C88B3b23E12DBd); 

    uint immutable timeout =1000;
    AcceptWithTimeout verifier;

    function setUp(
    ) public {
        verifier = new AcceptWithTimeout(timeout, DUMMY_SOCKET, DUMMY_MANAGER);
                vm.prank(DUMMY_MANAGER);
                verifier.Activate();
    }

    function testDeployment() public {
        assertEq(verifier.manager(), DUMMY_MANAGER); 
        assertEq(verifier.socket(), DUMMY_SOCKET); 
        bool isActive = verifier.isActive();
        assertTrue(isActive);
        
    }

    function testPausing() public {
        uint256 chainId =1;

        prankAndAddPauser(DUMMY_PAUSER,chainId);

        bool isPauser = verifier.IsPauser(DUMMY_PAUSER, chainId);
        assertTrue(isPauser);

        vm.prank(DUMMY_SOCKET);
        verifier.PreExecHook();

        vm.prank(DUMMY_PAUSER);
        verifier.Pause(chainId);

        assertFalse(verifier.isActive());
    }

    function testFailPausing() public {
        uint256 chainId =1;

        prankAndAddPauser(DUMMY_PAUSER, chainId);

        bool isPauser =verifier.IsPauser(DUMMY_PAUSER,chainId);
        assertTrue(isPauser);

        vm.prank(DUMMY_SOCKET);
        verifier.PreExecHook();

        vm.prank(DUMMY_PAUSER);
        verifier.Pause(chainId);

        verifier.PreExecHook();
    }

    function prankAndAddPauser(address pauser, uint256 chainId) internal { 
        vm.prank(DUMMY_MANAGER);
        verifier.AddPauser(pauser, chainId);
    }
}

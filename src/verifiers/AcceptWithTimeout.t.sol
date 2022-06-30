// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import {AcceptWithTimeout} from "./AcceptWithTimeout.sol";

contract AcceptWithTimeoutTest is Test{
    address DUMMY_MANAGER = address(0x75bbC04fA183dd0ac75857a0400F93f766748f01); 
    address DUMMY_SOCKET = address(0x75bbC04fa183dd0aC75857A0400F93f766748f02); 

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
        address pauser = msg.sender;

        vm.prank(DUMMY_MANAGER);
        verifier.AddPauser(pauser, chainId);

        bool isPauser = verifier.isPauserPerIncomingChain(pauser,chainId);
        assertTrue(isPauser);

        verifier.PreExecHook();

        vm.prank(pauser);
        verifier.Pause(chainId);

        assertTrue(!verifier.isActive());
    }

    function testFailPausing() public {
        uint256 chainId =1;
        address pauser = msg.sender;

        vm.prank(DUMMY_MANAGER);
        verifier.AddPauser(pauser, chainId);

        bool isPauser = verifier.isPauserPerIncomingChain(pauser,chainId);
        assertTrue(isPauser);

        verifier.PreExecHook();

        vm.prank(pauser);
        verifier.Pause(chainId);

        verifier.PreExecHook();
    }
}

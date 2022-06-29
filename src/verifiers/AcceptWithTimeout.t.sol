// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import {AcceptWithTimeout} from "./AcceptWithTimeout.sol";

contract AcceptWithTimeoutTest is DSTest {
    function setUp() public {}

    function testDeployment() public {
	AcceptWithTimeout verifier = new AcceptWithTimeout(100, address(0), address(0));
	emit log_address(address(verifier));
        assertTrue(true);
    }
}

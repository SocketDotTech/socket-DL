// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/mocks/MockAccessControl.sol";

contract AccessControlTest is Test {
    address constant _owner = address(1);
    address constant _giraffe_0 = address(2);
    address constant _giraffe_1 = address(3);
    address constant _hippo_0 = address(4);
    address constant _hippo_1 = address(5);
    address constant _ape = address(6);
    MockAccessControl _mac;
    bytes32 ROLE_GIRAFFE;
    bytes32 ROLE_HIPPO;

    function setUp() external {
        _mac = new MockAccessControl(_owner);
        ROLE_GIRAFFE = _mac.ROLE_GIRAFFE();
        ROLE_HIPPO = _mac.ROLE_HIPPO();
    }

    function testOwnerSet() external {
        address owner = _mac.owner();
        assertEq(owner, _owner);
    }

    function testGrantRole() external {
        _grant(ROLE_GIRAFFE, _giraffe_0);
        assertTrue(
            _mac.hasRole(ROLE_GIRAFFE, _giraffe_0),
            "Giraffe no get role"
        );
    }

    function testRevokeRole() external {
        _grant(ROLE_GIRAFFE, _giraffe_0);
        _revoke(ROLE_GIRAFFE, _giraffe_0);
        assertFalse(
            _mac.hasRole(ROLE_GIRAFFE, _giraffe_0),
            "Giraffe still got role"
        );
    }

    function testGiraffeFunction() external {
        _grantAllRoles();
        _callGiraffeFunction(_giraffe_0, true);
        _callGiraffeFunction(_giraffe_1, true);
        _callGiraffeFunction(_hippo_1, false);
        _callGiraffeFunction(_hippo_1, false);
        _callGiraffeFunction(_ape, false);
    }

    function testHippoFunction() external {
        _grantAllRoles();
        _callHippoFunction(_giraffe_0, false);
        _callHippoFunction(_giraffe_1, false);
        _callHippoFunction(_hippo_1, true);
        _callHippoFunction(_hippo_1, true);
        _callHippoFunction(_ape, false);
    }

    function testAnimalFunction() external {
        _grantAllRoles();
        _callAnimalFunction(_giraffe_0);
        _callAnimalFunction(_giraffe_1);
        _callAnimalFunction(_hippo_1);
        _callAnimalFunction(_hippo_1);
        _callAnimalFunction(_ape);
    }

    function _callGiraffeFunction(address caller, bool success) private {
        hoax(caller);
        if (!success) {
            vm.expectRevert(
                abi.encodeWithSelector(AccessControl.NoPermit.selector, ROLE_GIRAFFE)
            );
        }
        _mac.giraffe();
    }

    function _callHippoFunction(address caller, bool success) private {
        hoax(caller);
        if (!success) {
            vm.expectRevert(
                abi.encodeWithSelector(AccessControl.NoPermit.selector, ROLE_HIPPO)
            );
        }
        _mac.hippo();
    }

    function _callAnimalFunction(address caller) private {
        hoax(caller);
        _mac.animal();
    }

    function _grantAllRoles() private {
        _grant(ROLE_GIRAFFE, _giraffe_0);
        _grant(ROLE_GIRAFFE, _giraffe_1);
        _grant(ROLE_HIPPO, _hippo_0);
        _grant(ROLE_HIPPO, _hippo_1);
    }

    function _grant(bytes32 role, address user) private {
        hoax(_owner);
        _mac.grantRole(role, user);
    }

    function _revoke(bytes32 role, address user) private {
        hoax(_owner);
        _mac.revokeRole(role, user);
    }
}

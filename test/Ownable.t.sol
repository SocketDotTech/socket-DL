// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/mocks/MockOwnable.sol";

contract OwnableTest is Test {
    address constant _bob = address(1);
    address constant _owner = address(2);
    address constant _newOwner = address(3);
    MockOwnable _mo;

    function setUp() external {
        _mo = new MockOwnable(_owner);
    }

    function testOwnerSet() external {
        address owner = _mo.owner();
        assertEq(owner, _owner);
    }

    function testOwnableFunction() external {
        hoax(_owner);
        _mo.ownerFunction();

        hoax(_bob);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        _mo.ownerFunction();
    }

    function testPublicFunction() external {
        hoax(_owner);
        _mo.publicFunction();

        hoax(_bob);
        _mo.publicFunction();
    }

    function testNominate() external {
        hoax(_bob);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        _mo.nominateOwner(_newOwner);

        hoax(_owner);
        _mo.nominateOwner(_newOwner);
    }

    function testClaimOwner() external {
        hoax(_owner);
        _mo.nominateOwner(_newOwner);

        assertEq(_mo.nominee(), _newOwner);
        hoax(_bob);
        vm.expectRevert(Ownable.OnlyNominee.selector);
        _mo.claimOwner();

        hoax(_newOwner);
        _mo.claimOwner();
    }

    function testOwnableFunctionAfterChange() external {
        hoax(_owner);
        _mo.nominateOwner(_newOwner);

        hoax(_newOwner);
        _mo.claimOwner();

        hoax(_newOwner);
        _mo.ownerFunction();

        hoax(_owner);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        _mo.ownerFunction();

        hoax(_bob);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        _mo.ownerFunction();
    }
}

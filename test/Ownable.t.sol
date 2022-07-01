// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "../src/mocks/MockOwnable.sol";

contract OwnableTest is Test {
    address _bob = address(1);
    address _owner = address(2);
    address _newOwner = address(3);
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
        _mo.OwnerFunction();

        hoax(_bob);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        _mo.OwnerFunction();
    }

    function testPublicFunction() external {
        hoax(_owner);
        _mo.PublicFunction();

        hoax(_bob);
        _mo.PublicFunction();
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
        _mo.OwnerFunction();

        hoax(_owner);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        _mo.OwnerFunction();

        hoax(_bob);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        _mo.OwnerFunction();
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/vault/Vault.sol";

contract VaultTest is Test {
    address constant _owner = address(1);
    address constant _raju = address(2);
    Vault _vault;

    event FeeDeducted(uint256 amount_);

    function setUp() external {
        _vault = new Vault(_owner);
    }

    function testOwnerSet() external {
        address owner = _vault.owner();
        assertEq(owner, _owner);
    }

    function testDeductFee() external {
        vm.expectEmit(true, false, false, false);
        emit FeeDeducted(1000);
        _vault.deductFee{value: 1000}(0, 0);
        assertEq(address(_vault).balance, 1000);
    }

    function testClaimFee() external {
        _vault.deductFee{value: 1000}(0, 0);

        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        _vault.claimFee(_raju, 1000);

        uint256 initBal = _raju.balance;

        hoax(_owner);
        _vault.claimFee(address(_raju), 1000);

        uint256 finalBal = _raju.balance;

        assertEq(finalBal - initBal, 1000);
    }

    function testGetFees() external {
        assertEq(_vault.getFees(0, 0), 0);
    }
}

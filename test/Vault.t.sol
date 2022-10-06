// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/vault/Vault.sol";

contract VaultTest is Test {
    address constant _owner = address(1);
    address constant _raju = address(2);
    uint256 constant _minFees = 1000;
    uint256 constant _configId = 0;
    uint256 constant _remoteChainId = 0x0001;

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
        hoax(_owner);
        _vault.setFees(_minFees, _configId);

        vm.expectRevert(IVault.NotEnoughFees.selector);
        _vault.deductFee{value: 10}(0, _configId);

        vm.expectEmit(true, false, false, false);
        emit FeeDeducted(_minFees);

        _vault.deductFee{value: _minFees}(0, _configId);
        assertEq(address(_vault).balance, _minFees);
    }

    function testClaimFee() external {
        hoax(_owner);
        _vault.setFees(_minFees, _configId);
        _vault.deductFee{value: _minFees}(0, _configId);

        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        _vault.claimFee(_raju, 1000);

        uint256 initBal = _raju.balance;

        hoax(_owner);
        _vault.claimFee(address(_raju), 1000);

        uint256 finalBal = _raju.balance;

        assertEq(finalBal - initBal, 1000);
    }

    function testSetFees() external {
        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        _vault.setFees(_minFees, _configId);

        assertEq(_vault.getFees(_configId), 0);

        hoax(_owner);
        _vault.setFees(_minFees, _configId);

        assertEq(_vault.getFees(_configId), _minFees);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/vault/Vault.sol";

contract VaultTest is Test {
    address constant _owner = address(1);
    address constant _raju = address(2);
    uint256 constant _minFees = 1000;
    uint256 constant _remoteChainSlug = 0x0001;
    bytes32 constant _integrationType =
        keccak256(abi.encode("INTEGRATION_TYPE"));

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
        _vault.setFees(_minFees, _remoteChainSlug, _integrationType);

        vm.expectRevert(Vault.InsufficientFees.selector);
        _vault.deductFee{value: 10}(_remoteChainSlug, _integrationType);

        vm.expectEmit(true, false, false, false);
        emit FeeDeducted(_minFees);

        _vault.deductFee{value: _minFees}(_remoteChainSlug, _integrationType);
        assertEq(address(_vault).balance, _minFees);
    }

    function testClaimFee() external {
        hoax(_owner);
        _vault.setFees(_minFees, _remoteChainSlug, _integrationType);
        _vault.deductFee{value: _minFees}(_remoteChainSlug, _integrationType);

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
        _vault.setFees(_minFees, _remoteChainSlug, _integrationType);

        assertEq(_vault.getFees(_integrationType, _remoteChainSlug), 0);

        hoax(_owner);
        _vault.setFees(_minFees, _remoteChainSlug, _integrationType);

        assertEq(_vault.getFees(_integrationType, _remoteChainSlug), _minFees);
    }
}

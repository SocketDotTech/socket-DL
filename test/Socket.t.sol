// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Setup.t.sol";

contract SocketTest is Setup {
    uint256 constant srcChainId_ = 0x2013AA263;
    uint256 constant _destChainId = 0x2013AA264;
    string constant integrationType = "FAST";
    bytes32 private constant EXECUTOR_ROLE = keccak256("EXECUTOR");

    address accum_ = address(1);
    address deaccum_ = address(2);
    address verifier_ = address(3);

    function setUp() external {
        uint256[] memory attesters = new uint256[](1);
        attesters[0] = _attesterPrivateKey;

        _a = _deployContractsOnSingleChain(srcChainId_, _destChainId);
    }

    function testAddConfig() external {
        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        _a.socket__.addConfig(
            _destChainId,
            accum_,
            deaccum_,
            verifier_,
            integrationType
        );

        hoax(_socketOwner);
        _a.socket__.addConfig(
            _destChainId,
            accum_,
            deaccum_,
            verifier_,
            integrationType
        );

        bytes32 destConfigId = keccak256(abi.encode(_destChainId, integrationType));
        assertEq(_a.socket__.destConfigs(destConfigId), 1);

        (address accum, address deaccum, address verifier) = _a
            .socket__
            .getConfig(1);

        assertEq(accum, accum_);
        assertEq(deaccum, deaccum_);
        assertEq(verifier, verifier_);

        hoax(_socketOwner);
        vm.expectRevert(ISocket.ConfigExists.selector);
        _a.socket__.addConfig(
            _destChainId,
            accum_,
            deaccum_,
            verifier_,
            integrationType
        );
    }

    function testSetPlugConfig() external {
        hoax(_raju);
        vm.expectRevert(ISocket.InvalidConfigId.selector);
        _a.socket__.setPlugConfig(_destChainId, _raju, integrationType);

        hoax(_socketOwner);
        _a.socket__.addConfig(
            _destChainId,
            accum_,
            deaccum_,
            verifier_,
            integrationType
        );

        hoax(_raju);
        _a.socket__.setPlugConfig(_destChainId, _raju, integrationType);

        (
            address accum,
            address deaccum,
            address verifier,
            uint256 configId
        ) = _a.socket__.getPlugConfig(_destChainId, _raju);

        assertEq(accum, accum_);
        assertEq(deaccum, deaccum_);
        assertEq(verifier, verifier_);
        assertEq(configId, 1);
    }

    function testSetHasher() external {
        address newHasher = address(1000);

        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        _a.socket__.setHasher(newHasher);

        hoax(_socketOwner);
        _a.socket__.setHasher(newHasher);
        assertEq(address(_a.socket__.hasher()), newHasher);
    }

    function testSetVault() external {
        address newVault = address(1000);

        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        _a.socket__.setVault(newVault);

        hoax(_socketOwner);
        _a.socket__.setVault(newVault);
        assertEq(address(_a.socket__.vault()), newVault);
    }

    function testGrantExecutorRole() external {
        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        _a.socket__.grantExecutorRole(_attester);

        hoax(_socketOwner);
        _a.socket__.grantExecutorRole(_attester);

        assertTrue(_a.socket__.hasRole(EXECUTOR_ROLE, _attester));
    }

    function testRevokeExecutorRole() external {
        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        _a.socket__.revokeExecutorRole(_attester);

        hoax(_socketOwner);
        _a.socket__.grantExecutorRole(_attester);
        hoax(_socketOwner);
        _a.socket__.revokeExecutorRole(_attester);

        assertFalse(_a.socket__.hasRole(EXECUTOR_ROLE, _attester));
    }
}

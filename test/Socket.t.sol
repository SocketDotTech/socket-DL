// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Setup.t.sol";

contract SocketTest is Setup {
    uint256 constant srcChainSlug_ = 1;
    uint256 constant dstChainSlug = 2;
    string constant integrationType = "FAST";
    bytes32 private constant EXECUTOR_ROLE = keccak256("EXECUTOR");

    uint256 msgGasLimit = 130000;

    function setUp() external {
        uint256[] memory attesters = new uint256[](1);
        attesters[0] = _attesterPrivateKey;

        _a = _deployContractsOnSingleChain(srcChainSlug_, dstChainSlug);
    }

    function testAddConfig() external {
        hoax(_socketOwner);
        _a.socket__.addConfig(
            dstChainSlug,
            address(_a.fastCapacitor__),
            address(_a.decapacitor__),
            address(_a.verifier__),
            integrationType
        );

        (address capacitor, address decapacitor, address verifier) = _a
            .socket__
            .getConfigs(dstChainSlug, integrationType);

        assertEq(capacitor, address(_a.fastCapacitor__));
        assertEq(decapacitor, address(_a.decapacitor__));
        assertEq(verifier, address(_a.verifier__));

        hoax(_socketOwner);
        vm.expectRevert(SocketConfig.ConfigExists.selector);
        _a.socket__.addConfig(
            dstChainSlug,
            address(_a.fastCapacitor__),
            address(_a.decapacitor__),
            address(_a.verifier__),
            integrationType
        );
    }

    function testSetPlugConfig() external {
        hoax(_raju);
        vm.expectRevert(SocketConfig.InvalidIntegrationType.selector);
        _a.socket__.setPlugConfig(
            dstChainSlug,
            _raju,
            integrationType,
            integrationType
        );

        _a.socket__.addConfig(
            dstChainSlug,
            address(_a.fastCapacitor__),
            address(_a.decapacitor__),
            address(_a.verifier__),
            integrationType
        );

        hoax(_raju);
        _a.socket__.setPlugConfig(
            dstChainSlug,
            _raju,
            integrationType,
            integrationType
        );

        (
            address capacitor,
            address decapacitor,
            address verifier,
            address remotePlug,
            ,

        ) = _a.socket__.getPlugConfig(dstChainSlug, _raju);

        assertEq(capacitor, address(_a.fastCapacitor__));
        assertEq(decapacitor, address(_a.decapacitor__));
        assertEq(verifier, address(_a.verifier__));
        assertEq(remotePlug, _raju);
    }

    function testSetHasher() external {
        address newHasher = address(1000);

        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        _a.socket__.setHasher(newHasher);

        hoax(_socketOwner);
        _a.socket__.setHasher(newHasher);
        assertEq(address(_a.socket__._hasher__()), newHasher);
    }

    function testSetVault() external {
        address newVault = address(1000);

        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        _a.socket__.setVault(newVault);

        hoax(_socketOwner);
        _a.socket__.setVault(newVault);
        assertEq(address(_a.socket__._vault__()), newVault);
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

    function testOutboundWithoutConfig() external {
        // should revert if no config set
        vm.expectRevert();
        _a.socket__.outbound(dstChainSlug, msgGasLimit, bytes("payload"));
    }
}

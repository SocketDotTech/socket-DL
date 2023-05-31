// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../Setup.t.sol";
import "../../contracts/CapacitorFactory.sol";
import {RESCUE_ROLE} from "../../contracts/utils/AccessRoles.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract CapacitorFactoryTest is Setup {
    address immutable _owner = address(uint160(c++));

    uint256 tokenSupply = 10000;
    uint32 siblingChainSlug = 80001;

    CapacitorFactory _cf;
    ERC20PresetFixedSupply _token;
    error NoPermit(bytes32 role);

    function setUp() external {
        _cf = new CapacitorFactory(_owner);
        _token = new ERC20PresetFixedSupply("TEST", "T", tokenSupply, _owner);
    }

    function testDeploySingleCapacitor() external {
        (ICapacitor singleCapacitor, IDecapacitor singleDecapacitor) = _cf
            .deploy(1, siblingChainSlug, DEFAULT_BATCH_LENGTH);

        assertEq(
            address(singleCapacitor),
            0x104fBc016F4bb334D775a19E8A6510109AC63E00
        );
        assertEq(
            address(singleDecapacitor),
            0x037eDa3aDB1198021A9b2e88C22B464fD38db3f3
        );
    }

    function testDeployHashChainCapacitor() external {
        (ICapacitor singleCapacitor, IDecapacitor singleDecapacitor) = _cf
            .deploy(2, siblingChainSlug, DEFAULT_BATCH_LENGTH);

        assertEq(
            address(singleCapacitor),
            0x104fBc016F4bb334D775a19E8A6510109AC63E00
        );
        assertEq(
            address(singleDecapacitor),
            0x037eDa3aDB1198021A9b2e88C22B464fD38db3f3
        );
    }

    function testDeploy(uint256 capacitorType) external {
        if (capacitorType != 1 && capacitorType != 2) {
            vm.expectRevert(ICapacitorFactory.InvalidCapacitorType.selector);
        }

        _cf.deploy(capacitorType, siblingChainSlug, DEFAULT_BATCH_LENGTH);
    }

    function testRescueFunds() external {
        uint256 amount = 1000;

        vm.startPrank(_owner);
        _cf.grantRole(RESCUE_ROLE, _owner);
        vm.stopPrank();

        hoax(_owner);
        _token.transfer(address(_cf), amount);

        uint256 initialBalOfOwner = _token.balanceOf(_raju);

        hoax(_raju);
        bytes4 selector = bytes4(keccak256("NoPermit(bytes32)"));
        vm.expectRevert(abi.encodeWithSelector(selector, RESCUE_ROLE));

        _cf.rescueFunds(address(_token), _raju, amount);

        hoax(_owner);
        _cf.rescueFunds(address(_token), _raju, amount);

        uint256 finalBalOfOwner = _token.balanceOf(_raju);
        assertEq(finalBalOfOwner - initialBalOfOwner, amount);
    }
}

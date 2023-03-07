// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "../../contracts/CapacitorFactory.sol";

contract CapacitorFactoryTest is Test {
    uint256 internal c = 1;
    address immutable _owner = address(uint160(c++));
    address immutable _raju = address(uint160(c++));

    uint256 tokenSupply = 10000;
    uint256 siblingChainSlug = 80001;

    CapacitorFactory _cf;
    ERC20PresetFixedSupply _token;

    function setUp() external {
        hoax(_owner);
        _cf = new CapacitorFactory();
        _token = new ERC20PresetFixedSupply("TEST", "T", tokenSupply, _owner);
    }

    function testDeploySingleCapacitor() external {
        (ICapacitor singleCapacitor, IDecapacitor singleDecapacitor) = _cf
            .deploy(1, siblingChainSlug);
        assertEq(
            address(singleCapacitor),
            0x582e4a5B8F0c154922e086061cC6Dd07F056EAC1
        );
        assertEq(
            address(singleDecapacitor),
            0x0636b2c3241e32Be3dD768C063D278d9ba7bbcB1
        );
    }

    function testDeployHashChainCapacitor() external {
        (ICapacitor singleCapacitor, IDecapacitor singleDecapacitor) = _cf
            .deploy(2, siblingChainSlug);
        assertEq(
            address(singleCapacitor),
            0x582e4a5B8F0c154922e086061cC6Dd07F056EAC1
        );
        assertEq(
            address(singleDecapacitor),
            0x0636b2c3241e32Be3dD768C063D278d9ba7bbcB1
        );
    }

    function testDeploy(uint256 capacitorType) external {
        if (capacitorType != 1 && capacitorType != 2) {
            vm.expectRevert(ICapacitorFactory.InvalidCapacitorType.selector);
        }

        _cf.deploy(capacitorType, siblingChainSlug);
    }

    function testRescueFunds() external {
        uint256 amount = 1000;

        hoax(_owner);
        _token.transfer(address(_cf), amount);

        uint256 initialBalOfOwner = _token.balanceOf(_raju);

        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        _cf.rescueFunds(address(_token), _raju, amount);

        hoax(_owner);
        _cf.rescueFunds(address(_token), _raju, amount);

        uint256 finalBalOfOwner = _token.balanceOf(_raju);
        assertEq(finalBalOfOwner - initialBalOfOwner, amount);
    }
}

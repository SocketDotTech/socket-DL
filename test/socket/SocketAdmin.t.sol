// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../Setup.t.sol";

contract SocketSrcTest is Setup {
    Socket internal socket__;

    address newHasher = address(uint160(c++));
    address newTransmitManager = address(uint160(c++));
    address newExecutionManager = address(uint160(c++));
    address newCapacitorFactory = address(uint160(c++));

    function setUp() external {
        initialise();
        _a.chainSlug = uint32(uint256(aChainSlug));
        uint256[] memory transmitterPivateKeys = new uint256[](1);
        transmitterPivateKeys[0] = _transmitterPrivateKey;
        _deployContractsOnSingleChain(
            _a,
            bChainSlug,
            isExecutionOpen,
            transmitterPivateKeys
        );

        socket__ = _a.socket__;
    }

    function testSetHasher() public {
        assertEq(address(socket__.hasher__()), address(_a.hasher__));

        hoax(_raju);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                GOVERNANCE_ROLE
            )
        );
        socket__.setHasher(newHasher);

        hoax(_socketOwner);
        socket__.setHasher(newHasher);

        assertEq(address(socket__.hasher__()), newHasher);
    }

    function testSetTransmitManager() public {
        assertEq(
            address(socket__.transmitManager__()),
            address(_a.transmitManager__)
        );

        hoax(_raju);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                GOVERNANCE_ROLE
            )
        );
        socket__.setTransmitManager(newTransmitManager);

        hoax(_socketOwner);
        socket__.setTransmitManager(newTransmitManager);

        assertEq(address(socket__.transmitManager__()), newTransmitManager);
    }

    function testSetExecutionManager() public {
        assertEq(
            address(socket__.executionManager__()),
            address(_a.executionManager__)
        );

        hoax(_raju);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                GOVERNANCE_ROLE
            )
        );
        socket__.setExecutionManager(newExecutionManager);

        hoax(_socketOwner);
        socket__.setExecutionManager(newExecutionManager);

        assertEq(address(socket__.executionManager__()), newExecutionManager);
    }

    function testSetCapacitorFactory() public {
        assertEq(
            address(socket__.capacitorFactory__()),
            address(_a.capacitorFactory__)
        );

        hoax(_raju);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                GOVERNANCE_ROLE
            )
        );
        socket__.setCapacitorFactory(newCapacitorFactory);

        hoax(_socketOwner);
        socket__.setCapacitorFactory(newCapacitorFactory);

        assertEq(address(socket__.capacitorFactory__()), newCapacitorFactory);
    }
}

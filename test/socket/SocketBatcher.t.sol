// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../Setup.t.sol";
import "../../contracts/socket/SocketBatcher.sol";
import "../../contracts/examples/Counter.sol";

contract SocketBatcherTest is Setup {
    Counter srcCounter__;
    Counter dstCounter__;
    SocketBatcher batcher__;

    uint256 addAmount = 100;
    uint256 subAmount = 40;
    bool isFast = true;
    uint256 index = isFast ? 0 : 1;

    bytes32[] roots;

    event ExecutionSuccess(bytes32 msgId);
    event ExecutionFailed(bytes32 msgId, string result);
    event ExecutionFailedBytes(bytes32 msgId, bytes result);
    event PacketVerifiedAndSealed(
        address indexed transmitter,
        bytes32 indexed packetId,
        bytes32 root,
        bytes signature
    );

    function setUp() external {
        uint256[] memory transmitterPrivateKeys = new uint256[](1);
        transmitterPrivateKeys[0] = _transmitterPrivateKey;

        _dualChainSetup(transmitterPrivateKeys);
        _deployPlugContracts();

        _configPlugContracts(index);
        batcher__ = new SocketBatcher(address(this));
    }

    function _deployPlugContracts() internal {
        vm.startPrank(_plugOwner);

        // deploy counters
        srcCounter__ = new Counter(address(_a.socket__));
        dstCounter__ = new Counter(address(_b.socket__));

        vm.stopPrank();
    }

    function _configPlugContracts(uint256 socketConfigIndex) internal {
        hoax(_plugOwner);
        srcCounter__.setSocketConfig(
            _b.chainSlug,
            address(dstCounter__),
            address(_a.configs__[socketConfigIndex].switchboard__)
        );

        hoax(_plugOwner);
        dstCounter__.setSocketConfig(
            _a.chainSlug,
            address(srcCounter__),
            address(_b.configs__[socketConfigIndex].switchboard__)
        );
    }

    function testSealBatchWithoutSocketRelayerRole() external {
        // revoke the SOCKET_RELAYER_ROLE
        vm.prank(batcher__.owner());
        batcher__.revokeRole(SOCKET_RELAYER_ROLE, address(this));

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                SOCKET_RELAYER_ROLE
            )
        );
        batcher__.sealBatch(address(0), new SocketBatcher.SealRequest[](0));
    }

    function testProposeBatchWithoutSocketRelayerRole() external {
        // revoke the SOCKET_RELAYER_ROLE
        vm.prank(batcher__.owner());
        batcher__.revokeRole(SOCKET_RELAYER_ROLE, address(this));

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                SOCKET_RELAYER_ROLE
            )
        );
        batcher__.proposeBatch(address(0), new SocketBatcher.ProposeRequest[](0));
    }

    function testSendBatchWithoutSocketRelayerRole() external {
        // revoke the SOCKET_RELAYER_ROLE
        vm.prank(batcher__.owner());
        batcher__.revokeRole(SOCKET_RELAYER_ROLE, address(this));

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                SOCKET_RELAYER_ROLE
            )
        );

        batcher__.sendBatch(
            address(0),
            new SocketBatcher.SealRequest[](0),
            new SocketBatcher.ProposeRequest[](0),
            new SocketBatcher.AttestRequest[](0),
            new SocketBatcher.ExecuteRequest[](0)
        );
    }
    
    function testExecuteBatchWithoutSocketRelayerRole() external {
        // revoke the SOCKET_RELAYER_ROLE
        vm.prank(batcher__.owner());
        batcher__.revokeRole(SOCKET_RELAYER_ROLE, address(this));

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                SOCKET_RELAYER_ROLE
            )
        );
        batcher__.executeBatch(
            address(0),
            new SocketBatcher.ExecuteRequest[](0)
        );
    }

    function testReceiveMessageBatchWithoutSocketRelayerRole() external {
        // revoke the SOCKET_RELAYER_ROLE
        vm.prank(batcher__.owner());
        batcher__.revokeRole(SOCKET_RELAYER_ROLE, address(this));

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                SOCKET_RELAYER_ROLE
            )
        );
        batcher__.receiveMessageBatch(
            address(0),
            new SocketBatcher.ReceivePacketProofRequest[](0)
        );
    }

    function testInitiateArbitrumNativeBatch() public {
        SocketBatcher.ArbitrumNativeInitiatorRequest[] memory requests;

        // revoke the SOCKET_RELAYER_ROLE
        vm.prank(batcher__.owner());
        batcher__.revokeRole(SOCKET_RELAYER_ROLE, address(this));

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                SOCKET_RELAYER_ROLE
            )
        );
        batcher__.initiateArbitrumNativeBatch(
            address(0),
            address(0),
            address(0),
            requests
        );
    }

    function testWithdrawalsWithoutSocketRelayerRole() external {
        // revoke the SOCKET_RELAYER_ROLE
        vm.prank(batcher__.owner());
        batcher__.revokeRole(SOCKET_RELAYER_ROLE, address(this));

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                SOCKET_RELAYER_ROLE
            )
        );
        batcher__.withdrawals(new address payable[](0), new uint256[](0));
    }
}

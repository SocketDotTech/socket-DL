// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../../Setup.t.sol";
import "../../../contracts/mocks/MockPolygonL1Switchboard.sol";

// mainnet -> polygon
// Switchboard on mainnet (1) for polygon (137) as remote is: 0xDe5c161D61D069B0F2069518BB4110568D465465
// RemoteNativeSwitchBoard i.e SwitchBoard on polygon (137) is:0x029ce68B3A6B3B3713CaC23a39c9096f279c8Ad2
contract PolygonL1SwitchboardTest is Setup {
    bytes32[] roots;
    uint256 nonce;

    uint256 initiateGasLimit_ = 300000;
    uint256 executionOverhead_ = 300000;
    address checkpointManager_ = 0x86E4Dc95c7FBdBf52e33D563BbDB00823894C287;
    address fxRoot_ = 0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2;

    MockPolygonL1Switchboard polygonL1Switchboard;
    ICapacitor singleCapacitor;

    function setUp() external {
        initialize();

        _a.chainSlug = uint32(uint256(1));
        _b.chainSlug = uint32(uint256(137));

        uint256 fork = vm.createFork(vm.envString("MAINNET_RPC"));
        vm.selectFork(fork);

        uint256[] memory transmitterPrivateKeys = new uint256[](1);
        transmitterPrivateKeys[0] = _transmitterPrivateKey;

        _chainSetup(transmitterPrivateKeys);
    }

    function testInitateNativeConfirmation() public {
        address socketAddress = address(_a.socket__);

        vm.startPrank(socketAddress);

        ISocket.MessageDetails memory messageDetails;
        messageDetails.msgId = bytes32(0);
        messageDetails.minMsgGasLimit = 1000000;
        messageDetails.executionFee = 100;
        messageDetails.payload = abi.encode(msg.sender);

        bytes32 packedMessage = _a.hasher__.packMessage(
            _a.chainSlug,
            msg.sender,
            _b.chainSlug,
            address(1),
            messageDetails
        );

        singleCapacitor.addPackedMessage(packedMessage);

        (, bytes32 packetId, ) = _getLatestSignature(
            address(singleCapacitor),
            _a.chainSlug,
            _b.chainSlug
        );
        polygonL1Switchboard.initiateNativeConfirmation(packetId);
        vm.stopPrank();
    }

    function testReceivePacket() public {
        bytes32 root = bytes32("RANDOM_ROOT");
        bytes32 packetId = bytes32("RANDOM_PACKET");

        assertFalse(
            polygonL1Switchboard.allowPacket(
                root,
                packetId,
                uint256(0),
                uint32(0),
                uint256(0)
            )
        );

        bytes memory data = abi.encode(packetId, root);
        polygonL1Switchboard.receivePacket(data);

        assertTrue(
            polygonL1Switchboard.allowPacket(
                root,
                packetId,
                uint256(0),
                uint32(0),
                uint256(0)
            )
        );
    }

    function testNonBridgeReceivePacketCall() public {
        vm.expectRevert(bytes("ONLY_FX_CHILD"));
        polygonL1Switchboard.receivePacket(bytes32(0), bytes32(0));
    }

    function testSetFxChildTunnel() public {
        address childTunnel = address(uint160(c++));
        assertEq(address(polygonL1Switchboard.fxChildTunnel()), address(0));

        hoax(_raju);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                GOVERNANCE_ROLE
            )
        );
        polygonL1Switchboard.setFxChildTunnel(childTunnel);

        hoax(_socketOwner);
        polygonL1Switchboard.setFxChildTunnel(childTunnel);

        assertEq(address(polygonL1Switchboard.fxChildTunnel()), childTunnel);
    }

    function _chainSetup(uint256[] memory transmitterPrivateKeys_) internal {
        _deployContractsOnSingleChain(
            _a,
            _b.chainSlug,
            isExecutionOpen,
            transmitterPrivateKeys_
        );
        SocketConfigContext memory scc_ = addPolygonL1Switchboard(
            _a,
            _b.chainSlug,
            _capacitorType
        );
        _a.configs__.push(scc_);
    }

    function addPolygonL1Switchboard(
        ChainContext storage cc_,
        uint32 remoteChainSlug_,
        uint256 capacitorType_
    ) internal returns (SocketConfigContext memory scc_) {
        vm.startPrank(_socketOwner);

        polygonL1Switchboard = new MockPolygonL1Switchboard(
            cc_.chainSlug,
            checkpointManager_,
            fxRoot_,
            _socketOwner,
            address(cc_.socket__),
            cc_.sigVerifier__
        );

        polygonL1Switchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);
        vm.stopPrank();

        scc_ = _registerSwitchboardForSibling(
            cc_,
            _socketOwner,
            address(polygonL1Switchboard),
            0,
            remoteChainSlug_,
            capacitorType_,
            siblingSwitchboard
        );
        singleCapacitor = scc_.capacitor__;
    }
}

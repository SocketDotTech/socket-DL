// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../../Setup.t.sol";
import "../../../contracts/mocks/MockPolygonL2Switchboard.sol";

// Goerli -> mumbai
contract PolygonL2SwitchboardTest is Setup {
    bytes32[] roots;
    uint256 nonce;

    uint256 confirmGasLimit_ = 300000;
    uint256 initiateGasLimit_ = 300000;
    uint256 executionOverhead_ = 300000;
    address fxChild_ = 0xCf73231F28B7331BBe3124B907840A94851f9f11;
    address rootTunnel = address(uint160(c++));

    MockPolygonL2Switchboard polygonL2Switchboard;
    ICapacitor singleCapacitor;

    function setUp() external {
        initialize();
        _a.chainSlug = uint32(uint256(80001));
        _b.chainSlug = uint32(uint256(5));

        uint256[] memory transmitterPrivateKeys = new uint256[](1);
        transmitterPrivateKeys[0] = _transmitterPrivateKey;

        _chainSetup(transmitterPrivateKeys);
    }

    function testInitateNativeConfirmation() public {
        address socketAddress = address(_a.socket__);

        vm.startPrank(socketAddress);

        ISocket.MessageDetails memory messageDetails;
        messageDetails.msgId = 0;
        messageDetails.minMsgGasLimit = 1000000;
        messageDetails.executionFee = 100;
        messageDetails.payload = abi.encode(msg.sender);

        bytes32 packedMessage = _a.hasher__.packMessage(
            _a.chainSlug,
            msg.sender,
            _b.chainSlug,
            0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1,
            messageDetails
        );

        singleCapacitor.addPackedMessage(packedMessage);

        (, bytes32 packetId, ) = _getLatestSignature(
            address(singleCapacitor),
            _a.chainSlug,
            _b.chainSlug
        );
        polygonL2Switchboard.initiateNativeConfirmation(packetId);
        vm.stopPrank();
    }

    function testReceivePacket() public {
        bytes32 root = bytes32("RANDOM_ROOT");
        bytes32 packetId = bytes32("RANDOM_PACKET");

        assertFalse(
            polygonL2Switchboard.allowPacket(
                root,
                packetId,
                uint256(0),
                uint32(0),
                uint256(0)
            )
        );

        bytes memory data = abi.encode(packetId, root);

        vm.expectRevert(bytes("FxBaseChildTunnel: INVALID_SENDER_FROM_ROOT"));
        polygonL2Switchboard.receivePacket(0, address(uint160(c++)), data);

        polygonL2Switchboard.receivePacket(0, rootTunnel, data);

        assertTrue(
            polygonL2Switchboard.allowPacket(
                root,
                packetId,
                uint256(0),
                uint32(0),
                uint256(0)
            )
        );
    }

    function testNonBridgeReceivePacketCall() public {
        vm.expectRevert(bytes("ONLY_FX_ROOT"));
        polygonL2Switchboard.receivePacket(bytes32(0), bytes32(0));
    }

    function _chainSetup(uint256[] memory transmitterPrivateKeys_) internal {
        _deployContractsOnSingleChain(
            _a,
            _b.chainSlug,
            isExecutionOpen,
            transmitterPrivateKeys_
        );
        SocketConfigContext memory scc_ = addPolygonL2Switchboard(
            _a,
            _b.chainSlug,
            _capacitorType
        );
        _a.configs__.push(scc_);
    }

    function testSetFxRootTunnel() public {
        assertEq(address(polygonL2Switchboard.fxRootTunnel()), rootTunnel);

        address newRootTunnel = address(uint160(c++));
        hoax(_raju);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                GOVERNANCE_ROLE
            )
        );
        polygonL2Switchboard.setFxRootTunnel(newRootTunnel);

        hoax(_socketOwner);
        polygonL2Switchboard.setFxRootTunnel(newRootTunnel);

        assertEq(address(polygonL2Switchboard.fxRootTunnel()), newRootTunnel);
    }

    function testUpdateFxChild() public {
        address fxChild = address(uint160(c++));
        assertEq(address(polygonL2Switchboard.fxChild()), fxChild_);

        hoax(_raju);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                GOVERNANCE_ROLE
            )
        );
        polygonL2Switchboard.updateFxChild(fxChild);

        hoax(_socketOwner);
        polygonL2Switchboard.updateFxChild(fxChild);

        assertEq(address(polygonL2Switchboard.fxChild()), fxChild);
    }

    function addPolygonL2Switchboard(
        ChainContext storage cc_,
        uint32 remoteChainSlug_,
        uint256 capacitorType_
    ) internal returns (SocketConfigContext memory scc_) {
        vm.startPrank(_socketOwner);
        polygonL2Switchboard = new MockPolygonL2Switchboard(
            cc_.chainSlug,
            fxChild_,
            _socketOwner,
            address(cc_.socket__),
            cc_.sigVerifier__
        );

        polygonL2Switchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);
        polygonL2Switchboard.setFxRootTunnel(rootTunnel);
        vm.stopPrank();

        scc_ = _registerSwitchboardForSibling(
            cc_,
            _socketOwner,
            address(polygonL2Switchboard),
            0,
            remoteChainSlug_,
            capacitorType_,
            siblingSwitchboard
        );
        singleCapacitor = scc_.capacitor__;
    }
}

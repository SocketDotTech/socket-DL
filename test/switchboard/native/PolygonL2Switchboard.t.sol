// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.20;

import "../../Setup.t.sol";
import "../../../contracts/switchboard/native/PolygonL2Switchboard.sol";

// Goerli -> mumbai
contract PolygonL2SwitchboardTest is Setup {
    bytes32[] roots;
    uint256 nonce;

    uint256 confirmGasLimit_ = 300000;
    uint256 initiateGasLimit_ = 300000;
    uint256 executionOverhead_ = 300000;
    address fxChild_ = 0xCf73231F28B7331BBe3124B907840A94851f9f11;

    PolygonL2Switchboard polygonL2Switchboard;
    ICapacitor singleCapacitor;

    function setUp() external {
        initialise();
        _a.chainSlug = uint32(uint256(80001));
        _b.chainSlug = uint32(uint256(5));

        uint256[] memory transmitterPivateKeys = new uint256[](1);
        transmitterPivateKeys[0] = _transmitterPrivateKey;

        _chainSetup(transmitterPivateKeys);
    }

    function testInitateNativeConfirmation() public {
        address socketAddress = address(_a.socket__);

        vm.startPrank(socketAddress);

        ISocket.MessageDetails memory messageDetails;
        messageDetails.msgId = 0;
        messageDetails.msgGasLimit = 1000000;
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

    function testNonBridgeReceivePacketCall() public {
        vm.expectRevert(bytes("ONLY_FX_CHILD"));
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
        address rootTunnel = address(uint160(c++));
        assertEq(address(polygonL2Switchboard.fxRootTunnel()), address(0));

        hoax(_raju);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                GOVERNANCE_ROLE
            )
        );
        polygonL2Switchboard.setFxRootTunnel(rootTunnel);

        hoax(_socketOwner);
        polygonL2Switchboard.setFxRootTunnel(rootTunnel);

        assertEq(address(polygonL2Switchboard.fxRootTunnel()), rootTunnel);
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
        polygonL2Switchboard = new PolygonL2Switchboard(
            cc_.chainSlug,
            fxChild_,
            _socketOwner,
            address(cc_.socket__),
            cc_.sigVerifier__
        );

        polygonL2Switchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);
        vm.stopPrank();

        scc_ = _registerSwitchboard(
            cc_,
            _socketOwner,
            address(polygonL2Switchboard),
            0,
            remoteChainSlug_,
            capacitorType_
        );
        singleCapacitor = scc_.capacitor__;
    }
}

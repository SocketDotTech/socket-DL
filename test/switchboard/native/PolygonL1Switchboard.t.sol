// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../../Setup.t.sol";
import "../../../contracts/switchboard/native/PolygonL1Switchboard.sol";

// Goerli -> mumbai
// Switchboard on Goerli (5) for mumbai-testnet (80001) as remote is: 0xDe5c161D61D069B0F2069518BB4110568D465465
// RemoteNativeSwitchBoard i.e SwitchBoard on mumbai-testnet (80001) is:0x029ce68B3A6B3B3713CaC23a39c9096f279c8Ad2
contract PolygonL1SwitchboardTest is Setup {
    bytes32[] roots;
    uint256 nonce;

    uint256 initiateGasLimit_ = 300000;
    uint256 executionOverhead_ = 300000;
    address checkpointManager_ = 0x2890bA17EfE978480615e330ecB65333b880928e;
    address fxRoot_ = 0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA;
    address remoteNativeSwitchboard_ =
        0x029ce68B3A6B3B3713CaC23a39c9096f279c8Ad2;

    PolygonL1Switchboard polygonL1Switchboard;
    ICapacitor singleCapacitor;

    function setUp() external {
        initialise();

        _a.chainSlug = uint32(uint256(5));
        _b.chainSlug = uint32(uint256(80001));

        uint256 fork = vm.createFork(vm.envString("GOERLI_RPC"), 8546583);
        vm.selectFork(fork);

        uint256[] memory transmitterPivateKeys = new uint256[](1);
        transmitterPivateKeys[0] = _transmitterPrivateKey;

        _chainSetup(transmitterPivateKeys);
    }

    function testInitateNativeConfirmation() public {
        address socketAddress = address(_a.socket__);

        vm.startPrank(socketAddress);

        ISocket.MessageDetails memory messageDetails;
        messageDetails.msgId = bytes32(0);
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
        polygonL1Switchboard.initiateNativeConfirmation(packetId);
        vm.stopPrank();
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

        polygonL1Switchboard = new PolygonL1Switchboard(
            cc_.chainSlug,
            checkpointManager_,
            fxRoot_,
            _socketOwner,
            address(cc_.socket__),
            cc_.sigVerifier__
        );

        polygonL1Switchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);
        vm.stopPrank();

        scc_ = _registerSwitchboard(
            cc_,
            _socketOwner,
            address(polygonL1Switchboard),
            0,
            remoteChainSlug_,
            capacitorType_
        );
        singleCapacitor = scc_.capacitor__;
    }
}

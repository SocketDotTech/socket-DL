// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

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
            _a,
            address(singleCapacitor),
            _b.chainSlug
        );
        polygonL2Switchboard.initiateNativeConfirmation(packetId);
        vm.stopPrank();
    }

    function testNonBridgeReceivePacketCall() public {
        vm.expectRevert("ONLY_FX_CHILD");
        polygonL2Switchboard.receivePacket(bytes32(0), bytes32(0));
    }

    function _chainSetup(uint256[] memory transmitterPrivateKeys_) internal {
        _deployContractsOnSingleChain(
            _a,
            _b.chainSlug,
            transmitterPrivateKeys_
        );
        SocketConfigContext memory scc_ = addPolygonL2Switchboard(
            _a,
            _b.chainSlug,
            _capacitorType
        );
        _a.configs__.push(scc_);
    }

    function addPolygonL2Switchboard(
        ChainContext storage cc_,
        uint32 remoteChainSlug_,
        uint256 capacitorType_
    ) internal returns (SocketConfigContext memory scc_) {
        polygonL2Switchboard = new PolygonL2Switchboard(
            cc_.chainSlug,
            fxChild_,
            _socketOwner,
            address(cc_.socket__),
            cc_.sigVerifier__
        );

        scc_ = registerSwitchbaord(
            cc_,
            _socketOwner,
            address(polygonL2Switchboard),
            remoteChainSlug_,
            capacitorType_
        );
    }

    function registerSwitchbaord(
        ChainContext storage cc_,
        address deployer_,
        address switchBoardAddress_,
        uint32 remoteChainSlug_,
        uint256 capacitorType_
    ) internal returns (SocketConfigContext memory scc_) {
        vm.startPrank(deployer_);
        cc_.socket__.registerSwitchBoard(
            switchBoardAddress_,
            DEFAULT_BATCH_LENGTH,
            uint32(remoteChainSlug_),
            capacitorType_
        );

        scc_.siblingChainSlug = remoteChainSlug_;
        scc_.capacitor__ = cc_.socket__.capacitors__(
            switchBoardAddress_,
            remoteChainSlug_
        );
        singleCapacitor = scc_.capacitor__;

        scc_.decapacitor__ = cc_.socket__.decapacitors__(
            switchBoardAddress_,
            remoteChainSlug_
        );
        scc_.switchboard__ = ISwitchboard(switchBoardAddress_);

        polygonL2Switchboard.grantRole(GOVERNANCE_ROLE, deployer_);
        vm.stopPrank();
    }
}

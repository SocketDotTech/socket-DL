// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.20;

import "../../Setup.t.sol";
import "../../../contracts/switchboard/native/ArbitrumL2Switchboard.sol";

// Arbitrum Goerli -> Goerli
contract ArbitrumL2SwitchboardTest is Setup {
    bytes32[] roots;
    uint256 nonce;

    uint256 initiateGasLimit_ = 100;
    uint256 executionOverhead_ = 100;
    address remoteNativeSwitchboard_ =
        0x3f0121d91B5c04B716Ea960790a89b173da7929c;

    ArbitrumL2Switchboard arbitrumL2Switchboard;
    ICapacitor singleCapacitor;

    function setUp() external {
        initialise();

        _a.chainSlug = uint32(uint256(421613));
        _b.chainSlug = uint32(uint256(5));

        uint256[] memory transmitterPivateKeys = new uint256[](1);
        transmitterPivateKeys[0] = _transmitterPrivateKey;

        _chainSetup(transmitterPivateKeys);
    }

    function testInitateNativeConfirmation() public {
        address socketAddress = address(_a.socket__);

        vm.startPrank(socketAddress);

        deal(socketAddress, 2e18);

        ISocket.MessageDetails memory messageDetails;
        messageDetails.msgId = 0;
        messageDetails.msgGasLimit = 1000000;
        messageDetails.executionFee = 100;
        messageDetails.payload = abi.encode(msg.sender);

        bytes32 packedMessage = _a.hasher__.packMessage(
            _a.chainSlug,
            msg.sender,
            _b.chainSlug,
            address(arbitrumL2Switchboard.arbsys__()),
            messageDetails
        );

        singleCapacitor.addPackedMessage(packedMessage);

        (, bytes32 packetId, ) = _getLatestSignature(
            address(singleCapacitor),
            _a.chainSlug,
            _b.chainSlug
        );
        vm.mockCall(
            address(arbitrumL2Switchboard.arbsys__()),
            abi.encodeWithSelector(
                arbitrumL2Switchboard.arbsys__().sendTxToL1.selector
            ),
            abi.encode("0x")
        );

        arbitrumL2Switchboard.initiateNativeConfirmation(packetId);
        vm.stopPrank();
    }

    function testReceivePacket() public {
        bytes32 root = bytes32("RANDOM_ROOT");
        bytes32 packetId = bytes32("RANDOM_PACKET");

        assertFalse(
            arbitrumL2Switchboard.allowPacket(
                root,
                packetId,
                uint256(0),
                uint32(0),
                uint256(0)
            )
        );

        vm.expectRevert(NativeSwitchboardBase.InvalidSender.selector);
        arbitrumL2Switchboard.receivePacket(packetId, root);

        address remoteAlias = AddressAliasHelper.applyL1ToL2Alias(
            remoteNativeSwitchboard_
        );
        hoax(remoteAlias);
        arbitrumL2Switchboard.receivePacket(packetId, root);

        assertTrue(
            arbitrumL2Switchboard.allowPacket(
                root,
                packetId,
                uint256(0),
                uint32(0),
                uint256(0)
            )
        );
    }

    function _chainSetup(uint256[] memory transmitterPrivateKeys_) internal {
        _deployContractsOnSingleChain(
            _a,
            _b.chainSlug,
            isExecutionOpen,
            transmitterPrivateKeys_
        );
        SocketConfigContext memory scc_ = addArbitrumL2Switchboard(
            _a,
            _b.chainSlug,
            _capacitorType
        );
        _a.configs__.push(scc_);
    }

    function addArbitrumL2Switchboard(
        ChainContext storage cc_,
        uint32 remoteChainSlug_,
        uint256 capacitorType_
    ) internal returns (SocketConfigContext memory scc_) {
        vm.startPrank(_socketOwner);

        arbitrumL2Switchboard = new ArbitrumL2Switchboard(
            cc_.chainSlug,
            _socketOwner,
            address(cc_.socket__),
            cc_.sigVerifier__
        );

        arbitrumL2Switchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);

        arbitrumL2Switchboard.updateRemoteNativeSwitchboard(
            remoteNativeSwitchboard_
        );
        vm.stopPrank();

        scc_ = _registerSwitchboard(
            cc_,
            _socketOwner,
            address(arbitrumL2Switchboard),
            0,
            remoteChainSlug_,
            capacitorType_
        );
        singleCapacitor = scc_.capacitor__;
    }
}

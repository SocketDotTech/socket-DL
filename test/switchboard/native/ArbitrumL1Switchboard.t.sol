// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../../Setup.t.sol";
import "../../../contracts/switchboard/native/ArbitrumL1Switchboard.sol";

// Goerli -> Arbitrum-Goerli
contract ArbitrumL1SwitchboardTest is Setup {
    bytes32[] roots;
    uint256 nonce;

    address remoteNativeSwitchboard_ =
        0x3f0121d91B5c04B716Ea960790a89b173da7929c;
    address inbox_ = 0x6BEbC4925716945D46F0Ec336D5C2564F419682C;
    address bridge_ = 0xaf4159A80B6Cc41ED517DB1c453d1Ef5C2e4dB72;
    address outbox_ = 0x0000000000000000000000000000000000000000;

    ArbitrumL1Switchboard arbitrumL1Switchboard;
    ICapacitor singleCapacitor;

    function setUp() external {
        initialise();

        _a.chainSlug = uint32(uint256(5));
        _b.chainSlug = uint32(uint256(421613));

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
            inbox_,
            messageDetails
        );

        singleCapacitor.addPackedMessage(packedMessage);

        (, bytes32 packetId, ) = _getLatestSignature(
            address(singleCapacitor),
            _a.chainSlug,
            _b.chainSlug
        );

        vm.mockCall(
            inbox_,
            abi.encodeWithSelector(
                arbitrumL1Switchboard.inbox__().createRetryableTicket.selector
            ),
            abi.encode("0x")
        );

        arbitrumL1Switchboard.initiateNativeConfirmation{value: 1e18}(
            packetId,
            10000,
            10000,
            1e16,
            _socketOwner,
            _socketOwner
        );
        vm.stopPrank();
    }

    function testUpdateInboxAddresses() public {
        address newInbox = address(uint160(c++));
        assertEq(address(arbitrumL1Switchboard.inbox__()), address(inbox_));

        hoax(_raju);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                GOVERNANCE_ROLE
            )
        );
        arbitrumL1Switchboard.updateInboxAddresses(newInbox);

        hoax(_socketOwner);
        arbitrumL1Switchboard.updateInboxAddresses(newInbox);

        assertEq(address(arbitrumL1Switchboard.inbox__()), newInbox);
    }

    function testUpdateBridge() public {
        address newBridge = address(uint160(c++));
        assertEq(address(arbitrumL1Switchboard.bridge__()), address(bridge_));

        hoax(_raju);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                GOVERNANCE_ROLE
            )
        );
        arbitrumL1Switchboard.updateBridge(newBridge);

        hoax(_socketOwner);
        arbitrumL1Switchboard.updateBridge(newBridge);

        assertEq(address(arbitrumL1Switchboard.bridge__()), newBridge);
    }

    function testUpdateOutbox() public {
        address newOutbox = address(uint160(c++));
        assertEq(address(arbitrumL1Switchboard.outbox__()), address(outbox_));

        hoax(_raju);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                GOVERNANCE_ROLE
            )
        );
        arbitrumL1Switchboard.updateOutbox(newOutbox);

        hoax(_socketOwner);
        arbitrumL1Switchboard.updateOutbox(newOutbox);

        assertEq(address(arbitrumL1Switchboard.outbox__()), newOutbox);
    }

    function _chainSetup(uint256[] memory transmitterPrivateKeys_) internal {
        _deployContractsOnSingleChain(
            _a,
            _b.chainSlug,
            isExecutionOpen,
            transmitterPrivateKeys_
        );
        SocketConfigContext memory scc_ = addArbitrumL1Switchboard(
            _a,
            _b.chainSlug,
            _capacitorType
        );
        _a.configs__.push(scc_);
    }

    function addArbitrumL1Switchboard(
        ChainContext storage cc_,
        uint32 remoteChainSlug_,
        uint256 capacitorType_
    ) internal returns (SocketConfigContext memory scc_) {
        vm.startPrank(_socketOwner);

        arbitrumL1Switchboard = new ArbitrumL1Switchboard(
            cc_.chainSlug,
            inbox_,
            _socketOwner,
            address(cc_.socket__),
            bridge_,
            outbox_,
            cc_.sigVerifier__
        );

        arbitrumL1Switchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);

        arbitrumL1Switchboard.updateRemoteNativeSwitchboard(
            remoteNativeSwitchboard_
        );
        vm.stopPrank();

        scc_ = _registerSwitchboard(
            cc_,
            _socketOwner,
            address(arbitrumL1Switchboard),
            0,
            remoteChainSlug_,
            capacitorType_
        );
        singleCapacitor = scc_.capacitor__;
    }
}

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

        bytes32 packedMessage = _a.hasher__.packMessage(
            _a.chainSlug,
            msg.sender,
            _b.chainSlug,
            inbox_,
            0,
            1000000,
            100,
            abi.encode(msg.sender)
        );

        singleCapacitor.addPackedMessage(packedMessage);

        (, bytes32 packetId, ) = _getLatestSignature(
            _a,
            address(singleCapacitor),
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

    function _chainSetup(uint256[] memory transmitterPrivateKeys_) internal {
        _deployContractsOnSingleChain(
            _a,
            _b.chainSlug,
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
        arbitrumL1Switchboard = new ArbitrumL1Switchboard(
            cc_.chainSlug,
            inbox_,
            _socketOwner,
            address(cc_.socket__),
            bridge_,
            outbox_,
            cc_.sigVerifier__
        );

        vm.startPrank(_socketOwner);
        arbitrumL1Switchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);

        arbitrumL1Switchboard.updateRemoteNativeSwitchboard(
            remoteNativeSwitchboard_
        );
        vm.stopPrank();

        scc_ = registerSwitchbaord(
            cc_,
            _socketOwner,
            address(arbitrumL1Switchboard),
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

        arbitrumL1Switchboard.grantRole(GOVERNANCE_ROLE, deployer_);
        vm.stopPrank();
    }
}

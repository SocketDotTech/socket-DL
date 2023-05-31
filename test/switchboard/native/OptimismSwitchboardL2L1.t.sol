// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../../Setup.t.sol";
import "../../../contracts/switchboard/native/OptimismSwitchboard.sol";

// Goerli -> Optimism-Goerli
// RemoteNativeSwitchBoard i.e SwitchBoard on Goerli (5) is:0x793753781B45565C68392c4BB556C1bEcFC42F24
contract OptimismSwitchboardL2L1Test is Setup {
    bytes32[] roots;
    uint256 nonce;

    uint256 receiveGasLimit_ = 100000;
    uint256 confirmGasLimit_ = 100000;
    uint256 initiateGasLimit_ = 100000;
    uint256 executionOverhead_ = 100000;
    address remoteNativeSwitchboard_ =
        0x793753781B45565C68392c4BB556C1bEcFC42F24;
    address crossDomainManagerAddress_ =
        0x4200000000000000000000000000000000000007;

    OptimismSwitchboard optimismSwitchboard;
    ICapacitor singleCapacitor;

    function setUp() external {
        initialise();

        _a.chainSlug = uint32(uint256(420));
        _b.chainSlug = uint32(uint256(5));

        uint256 fork = vm.createFork(
            vm.envString("OPTIMISM_GOERLI_RPC"),
            5911043
        );
        vm.selectFork(fork);

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
        optimismSwitchboard.initiateNativeConfirmation(packetId);
        vm.stopPrank();
    }

    function testReceivePacket() public {
        bytes32 packetId = bytes32(uint256(100));
        bytes32 root = bytes32(uint256(200));

        // call is not from crossDomainManagerAddress_
        vm.expectRevert(NativeSwitchboardBase.InvalidSender.selector);
        optimismSwitchboard.receivePacket(packetId, root);

        // call from wrong remoteNativeSwitchboard
        vm.mockCall(
            crossDomainManagerAddress_,
            abi.encodeWithSelector(
                optimismSwitchboard
                    .crossDomainMessenger__()
                    .xDomainMessageSender
                    .selector
            ),
            abi.encode(address(1))
        );

        hoax(crossDomainManagerAddress_);
        vm.expectRevert(NativeSwitchboardBase.InvalidSender.selector);
        optimismSwitchboard.receivePacket(packetId, root);

        // correct call
        vm.mockCall(
            crossDomainManagerAddress_,
            abi.encodeWithSelector(
                optimismSwitchboard
                    .crossDomainMessenger__()
                    .xDomainMessageSender
                    .selector
            ),
            abi.encode(optimismSwitchboard.remoteNativeSwitchboard())
        );

        vm.startPrank(crossDomainManagerAddress_);
        optimismSwitchboard.receivePacket(packetId, root);
        vm.stopPrank();
    }

    function _chainSetup(uint256[] memory transmitterPrivateKeys_) internal {
        _deployContractsOnSingleChain(
            _a,
            _b.chainSlug,
            transmitterPrivateKeys_
        );

        SocketConfigContext memory scc_ = addOptimismSwitchboard(
            _a,
            _b.chainSlug,
            _capacitorType
        );
        _a.configs__.push(scc_);
    }

    function addOptimismSwitchboard(
        ChainContext storage cc_,
        uint32 remoteChainSlug_,
        uint256 capacitorType_
    ) internal returns (SocketConfigContext memory scc_) {
        vm.startPrank(_socketOwner);

        optimismSwitchboard = new OptimismSwitchboard(
            cc_.chainSlug,
            receiveGasLimit_,
            _socketOwner,
            address(cc_.socket__),
            crossDomainManagerAddress_,
            cc_.sigVerifier__
        );

        optimismSwitchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);
        vm.stopPrank();

        scc_ = _registerSwitchboard(
            cc_,
            _socketOwner,
            address(optimismSwitchboard),
            0,
            remoteChainSlug_,
            capacitorType_
        );
        singleCapacitor = scc_.capacitor__;

        hoax(_socketOwner);
        optimismSwitchboard.updateRemoteNativeSwitchboard(
            remoteNativeSwitchboard_
        );
    }
}

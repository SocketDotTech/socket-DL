// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.20;

import "../Setup.t.sol";
import "../../contracts/capacitors/SingleCapacitor.sol";

contract SingleCapacitorTest is Setup {
    address immutable _socket = address(uint160(c++));
    bytes32 immutable _message_0 = bytes32(c++);
    bytes32 immutable _message_1 = bytes32(c++);
    bytes32 immutable _message_2 = bytes32(c++);

    SingleCapacitor _sa;
    SingleDecapacitor _sd;

    function setUp() external {
        initialise();

        hoax(_socketOwner);
        _sa = new SingleCapacitor(_socket, _socketOwner);
        _sd = new SingleDecapacitor(_socketOwner);
    }

    function testSingleCapacitorSetup() external {
        assertEq(_sa.owner(), _socketOwner, "Owner not set");

        assertTrue(_sa.socket() == _socket, "Socket role not set");

        _assertPacketById(bytes32(0), 0);
        _assertPacketToBeSealed(bytes32(0), 0);
    }

    function testAddMessage() external {
        _addPackedMessage(_message_0);
        _assertPacketById(_message_0, 0);
        _assertPacketToBeSealed(_message_0, 0);
    }

    function testSealPacket() external {
        vm.expectRevert(SingleCapacitor.NoPendingPacket.selector);
        _sealPacket();

        _addPackedMessage(_message_0);
        _sealPacket();
        _assertPacketById(_message_0, 0);
        _assertPacketById(bytes32(0), 1);
        _assertNextPacket(bytes32(0), 1);
    }

    function testAddWithoutSeal() external {
        _addPackedMessage(_message_0);
        _addPackedMessage(_message_1);
    }

    function testAddMessageMultiple() external {
        _addPackedMessage(_message_0);
        _addPackedMessage(_message_1);
        _addPackedMessage(_message_2);

        assertEq(_sa.getLatestPacketCount(), 2);
        (, uint256 packetToSeal) = _sa.getNextPacketToBeSealed();
        assertEq(packetToSeal, 0);

        // message_0
        _sealPacket();
        (, packetToSeal) = _sa.getNextPacketToBeSealed();
        assertEq(packetToSeal, 1);

        // message_1
        _sealPacket();
        (, packetToSeal) = _sa.getNextPacketToBeSealed();
        assertEq(packetToSeal, 2);

        // message_2
        (bytes32 root, uint256 packetId) = _sealPacket();
        (, packetToSeal) = _sa.getNextPacketToBeSealed();
        assertEq(packetToSeal, 3);

        assertEq(root, _message_2);
        assertEq(packetId, 2);

        _assertPacketById(_message_0, 0);
        _assertPacketById(_message_1, 1);
        _assertPacketById(_message_2, 2);

        _assertPacketById(bytes32(0), 3);
        _assertNextPacket(bytes32(0), 3);
    }

    function testAddMessageByRaju() external {
        vm.expectRevert(
            abi.encodeWithSelector(BaseCapacitor.OnlySocket.selector)
        );
        hoax(_raju);
        _sa.addPackedMessage(_message_0);
    }

    function testSealPacketByRaju() external {
        _addPackedMessage(_message_0);
        vm.expectRevert(
            abi.encodeWithSelector(BaseCapacitor.OnlySocket.selector)
        );
        hoax(_raju);
        _sa.sealPacket(0);
    }

    function testCapacitorRescueNativeFunds() public {
        uint256 amount = 1e18;
        hoax(_socketOwner);
        _rescueNative(address(_sa), NATIVE_TOKEN_ADDRESS, _fundRescuer, amount);
    }

    function testDecapacitorRescueNativeFunds() public {
        uint256 amount = 1e18;
        hoax(_socketOwner);
        _rescueNative(address(_sd), NATIVE_TOKEN_ADDRESS, _fundRescuer, amount);
    }

    function _assertPacketToBeSealed(bytes32 root_, uint256 packetId_) private {
        (bytes32 root, uint256 packetId) = _sa.getNextPacketToBeSealed();
        assertEq(root, root_, "Root Invalid");
        assertEq(packetId, packetId_, "packetId Invalid");
    }

    function _assertNextPacket(bytes32 root_, uint256 packetId_) private {
        uint64 nextPacketId = uint64(_sa.getLatestPacketCount() + 1);
        bytes32 root = _sa.getRootByCount(nextPacketId);
        assertEq(root, root_, "Root Invalid");
        assertEq(nextPacketId, packetId_, "packetId Invalid");
    }

    function _assertPacketById(bytes32 root_, uint64 packetId_) private {
        bytes32 root = _sa.getRootByCount(packetId_);
        assertEq(root, root_, "Root Invalid");
    }

    function _addPackedMessage(bytes32 packedMessage) private {
        hoax(_socket);
        _sa.addPackedMessage(packedMessage);
    }

    function _sealPacket() private returns (bytes32 root, uint256 packetId) {
        hoax(_socket);
        (root, packetId) = _sa.sealPacket(0);
    }
}

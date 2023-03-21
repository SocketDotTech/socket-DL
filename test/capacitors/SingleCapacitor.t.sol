// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../contracts/capacitors/SingleCapacitor.sol";

contract SingleCapacitorTest is Test {
    uint256 internal c = 1;
    address immutable _owner = address(uint160(c++));
    address immutable _socket = address(uint160(c++));
    address immutable _raju = address(uint160(c++));
    bytes32 immutable _message_0 = bytes32(c++);
    bytes32 immutable _message_1 = bytes32(c++);
    bytes32 immutable _message_2 = bytes32(c++);

    SingleCapacitor _sa;

    function setUp() external {
        hoax(_owner);
        _sa = new SingleCapacitor(_socket);
    }

    function testSetUp() external {
        assertEq(_sa.owner(), _owner, "Owner not set");

        assertTrue(
            _sa.hasRole(_sa.SOCKET_ROLE(), _socket),
            "Socket role not set"
        );

        _assertPacketById(bytes32(0), 0);
        _assertPacketToBeSealed(bytes32(0), 0);
    }

    function testSetSocket() external {
        address newSocket = address(uint160(c++));

        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        _sa.setSocket(newSocket);

        hoax(_owner);
        _sa.setSocket(newSocket);
        assertTrue(_sa.hasRole(_sa.SOCKET_ROLE(), newSocket));
    }

    function testAddMessage() external {
        _addPackedMessage(_message_0);
        _assertPacketById(_message_0, 0);
        _assertPacketToBeSealed(_message_0, 0);
    }

    function testSealPacket() external {
        vm.expectRevert(BaseCapacitor.NoPendingPacket.selector);
        _sealPacket();

        _addPackedMessage(_message_0);
        _sealPacket();
        _assertPacketById(_message_0, 0);
        _assertPacketById(bytes32(0), 1);
        _assertNextPacket(bytes32(0), 1);
    }

    function testAddMessageMultiple() external {
        _addPackedMessage(_message_0);
        _addPackedMessage(_message_1);
        _addPackedMessage(_message_2);

        assertEq(_sa._packets(), 3);

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
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                _sa.SOCKET_ROLE()
            )
        );
        hoax(_raju);
        _sa.addPackedMessage(_message_0);
    }

    function testSealPacketByRaju() external {
        _addPackedMessage(_message_0);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                _sa.SOCKET_ROLE()
            )
        );
        hoax(_raju);
        _sa.sealPacket();
    }

    function _assertPacketToBeSealed(bytes32 root_, uint256 packetId_) private {
        (bytes32 root, uint256 packetId) = _sa.getNextPacketToBeSealed();
        assertEq(root, root_, "Root Invalid");
        assertEq(packetId, packetId_, "packetId Invalid");
    }

    function _assertNextPacket(bytes32 root_, uint256 packetId_) private {
        uint256 nextPacketId = _sa.getLatestPacketCount() + 1;
        bytes32 root = _sa.getRootById(nextPacketId);
        assertEq(root, root_, "Root Invalid");
        assertEq(nextPacketId, packetId_, "packetId Invalid");
    }

    function _assertPacketById(bytes32 root_, uint256 packetId_) private {
        bytes32 root = _sa.getRootById(packetId_);
        assertEq(root, root_, "Root Invalid");
    }

    function _addPackedMessage(bytes32 packedMessage) private {
        hoax(_socket);
        _sa.addPackedMessage(packedMessage);
    }

    function _sealPacket() private returns (bytes32 root, uint256 packetId) {
        hoax(_socket);
        (root, packetId) = _sa.sealPacket();
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/accumulators/SingleAccum.sol";

contract SingleAccumTest is Test {
    address constant _owner = address(1);
    address constant _socket = address(2);
    address constant _raju = address(3);
    bytes32 constant _message_0 = bytes32(uint256(4));
    bytes32 constant _message_1 = bytes32(uint256(5));
    bytes32 constant _message_2 = bytes32(uint256(6));
    address constant _notary = address(7);
    SingleAccum _sa;

    function setUp() external {
        hoax(_owner);
        _sa = new SingleAccum(_socket, _notary);
    }

    function testSetUp() external {
        assertEq(_sa.owner(), _owner, "Owner not set");
        assertTrue(
            _sa.hasRole(_sa.SOCKET_ROLE(), _socket),
            "Socket role not set"
        );
        _assertPacketById(bytes32(0), 0);
        _assertNextPacket(bytes32(0), 0);
    }

    function testAddMessage() external {
        _addMessage(_message_0);
        _assertPacketById(_message_0, 0);
        _assertNextPacket(_message_0, 0);
    }

    function testSealPacket() external {
        _addMessage(_message_0);
        _sealPacket();
        _assertPacketById(_message_0, 0);
        _assertPacketById(bytes32(0), 1);
        _assertNextPacket(bytes32(0), 1);
    }

    function testAddWithoutSeal() external {
        _addMessage(_message_0);
        vm.expectRevert(SingleAccum.PendingPacket.selector);
        _addMessage(_message_1);
    }

    function testAddMessageMultiple() external {
        _addMessage(_message_0);
        _sealPacket();
        _addMessage(_message_1);
        _sealPacket();
        _addMessage(_message_2);
        _sealPacket();

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
        _sa.addMessage(_message_0);
    }

    function testSealPacketByRaju() external {
        _addMessage(_message_0);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                _sa.NOTARY_ROLE()
            )
        );
        hoax(_raju);
        _sa.sealPacket();
    }

    function _assertNextPacket(bytes32 root_, uint256 packetId_) private {
        (bytes32 root, uint256 packetId) = _sa.getNextPacket();
        assertEq(root, root_, "Root Invalid");
        assertEq(packetId, packetId_, "packetId Invalid");
    }

    function _assertPacketById(bytes32 root_, uint256 packetId_) private {
        bytes32 root = _sa.getRootById(packetId_);
        assertEq(root, root_, "Root Invalid");
    }

    function _addMessage(bytes32 packedMessage) private {
        hoax(_socket);
        _sa.addMessage(packedMessage);
    }

    function _sealPacket() private {
        hoax(_notary);
        _sa.sealPacket();
    }
}

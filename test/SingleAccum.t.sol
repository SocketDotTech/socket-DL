// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/accumulators/SingleAccum.sol";

contract SingleAccumTest is Test {
    address constant _owner = address(1);
    address constant _socket = address(2);
    address constant _raju = address(3);
    bytes32 constant _packet_0 = bytes32(uint256(4));
    bytes32 constant _packet_1 = bytes32(uint256(5));
    bytes32 constant _packet_2 = bytes32(uint256(6));
    SingleAccum _sa;

    function setUp() external {
        hoax(_owner);
        _sa = new SingleAccum(_socket);
    }

    function testSetUp() external {
        assertEq(_sa.owner(), _owner, "Owner not set");
        assertTrue(
            _sa.hasRole(_sa.SOCKET_ROLE(), _socket),
            "Socket role not set"
        );
        _assertBatchById(bytes32(0), 0);
        _assertNextBatch(bytes32(0), 0);
    }

    function testAddPacket() external {
        _addPacket(_packet_0);
        _assertBatchById(_packet_0, 0);
        _assertNextBatch(_packet_0, 0);
    }

    function testSealBatch() external {
        _addPacket(_packet_0);
        _sealBatch();
        _assertBatchById(_packet_0, 0);
        _assertBatchById(bytes32(0), 1);
        _assertNextBatch(bytes32(0), 1);
    }

    function testAddWithoutSeal() external {
        _addPacket(_packet_0);
        vm.expectRevert(SingleAccum.PendingPacket.selector);
        _addPacket(_packet_1);
    }

    function testAddPacketMultiple() external {
        _addPacket(_packet_0);
        _sealBatch();
        _addPacket(_packet_1);
        _sealBatch();
        _addPacket(_packet_2);
        _sealBatch();

        _assertBatchById(_packet_0, 0);
        _assertBatchById(_packet_1, 1);
        _assertBatchById(_packet_2, 2);

        _assertBatchById(bytes32(0), 3);
        _assertNextBatch(bytes32(0), 3);
    }

    function testAddPacketByRaju() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                _sa.SOCKET_ROLE()
            )
        );
        hoax(_raju);
        _sa.addPacket(_packet_0);
    }

    function testSealBatchByRaju() external {
        _addPacket(_packet_0);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                _sa.SOCKET_ROLE()
            )
        );
        hoax(_raju);
        _sa.sealBatch();
    }

    function _assertNextBatch(bytes32 root_, uint256 batchId_) private {
        (bytes32 root, uint256 batchId) = _sa.getNextBatch();
        assertEq(root, root_, "Root Invalid");
        assertEq(batchId, batchId_, "BatchId Invalid");
    }

    function _assertBatchById(bytes32 root_, uint256 batchId_) private {
        bytes32 root = _sa.getRootById(batchId_);
        assertEq(root, root_, "Root Invalid");
    }

    function _addPacket(bytes32 packetHash) private {
        hoax(_socket);
        _sa.addPacket(packetHash);
    }

    function _sealBatch() private {
        hoax(_socket);
        _sa.sealBatch();
    }
}

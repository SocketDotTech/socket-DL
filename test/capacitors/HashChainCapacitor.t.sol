// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../Setup.t.sol";
import {SOCKET_ROLE} from "../../contracts/utils/AccessRoles.sol";

contract HashChainCapacitorTest is Setup {
    address immutable _owner = address(uint160(c++));
    address immutable _socket = address(uint160(c++));

    bytes32 immutable _message_0 = bytes32(c++);
    bytes32 immutable _message_1 = bytes32(c++);
    bytes32 immutable _message_2 = bytes32(c++);
    bytes32[] internal roots;

    HashChainCapacitor _hcCapacitor;
    HashChainDecapacitor _hcDecapacitor;

    function setUp() external {
        hoax(_owner);
        _hcCapacitor = new HashChainCapacitor(_socket, _owner);
        _hcDecapacitor = new HashChainDecapacitor(_owner);
    }

    function testSetUp() external {
        assertEq(_hcCapacitor.owner(), _owner, "Owner not set");
        assertTrue(_hcCapacitor.socket() == _socket, "Socket role not set");
        _assertPacketById(bytes32(0), 0);
        _assertPacketToBeSealed(bytes32(0), 0);
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

    function testAddWithoutSeal() external {
        _addPackedMessage(_message_0);
        _addPackedMessage(_message_1);
    }

    function testAddMessageMultiple() external {
        _addPackedMessage(_message_0);
        _addPackedMessage(_message_1);
        _addPackedMessage(_message_2);

        assertEq(_hcCapacitor.getLatestPacketCount(), 0);
        (, uint256 packetToSeal) = _hcCapacitor.getNextPacketToBeSealed();
        assertEq(packetToSeal, 0);

        _sealPacket();
        (, packetToSeal) = _hcCapacitor.getNextPacketToBeSealed();
        assertEq(packetToSeal, 1);

        bytes32 hashedRoot = keccak256(abi.encode(bytes32(0), _message_0));

        hashedRoot = keccak256(abi.encode(hashedRoot, _message_1));

        hashedRoot = keccak256(abi.encode(hashedRoot, _message_2));

        bytes32 root = _hcCapacitor.getRootByCount(uint64(0));
        assertEq(root, hashedRoot);

        roots.push(_message_0);
        roots.push(_message_1);
        roots.push(_message_2);
        bytes memory proof = abi.encode(roots);
        assertTrue(
            _hcDecapacitor.verifyMessageInclusion(hashedRoot, _message_0, proof)
        );
        assertTrue(
            _hcDecapacitor.verifyMessageInclusion(hashedRoot, _message_1, proof)
        );
        assertTrue(
            _hcDecapacitor.verifyMessageInclusion(hashedRoot, _message_2, proof)
        );
    }

    function testAddMessageByRaju() external {
        vm.expectRevert(
            abi.encodeWithSelector(BaseCapacitor.OnlySocket.selector)
        );
        hoax(_raju);
        _hcCapacitor.addPackedMessage(_message_0);
    }

    function testSealPacketByRaju() external {
        _addPackedMessage(_message_0);
        vm.expectRevert(
            abi.encodeWithSelector(BaseCapacitor.OnlySocket.selector)
        );
        hoax(_raju);
        _hcCapacitor.sealPacket(DEFAULT_BATCH_LENGTH);
    }

    function _assertPacketToBeSealed(bytes32, uint256 packetId_) private {
        (, uint256 packetId) = _hcCapacitor.getNextPacketToBeSealed();
        assertEq(packetId, packetId_, "packetId Invalid");
    }

    function _assertNextPacket(bytes32 root_, uint256 packetId_) private {
        uint64 nextPacketId = uint64(_hcCapacitor.getLatestPacketCount() + 1);
        bytes32 root = _hcCapacitor.getRootByCount(nextPacketId);
        assertEq(root, root_, "Root Invalid");
        assertEq(nextPacketId, packetId_, "packetId Invalid");
    }

    function _assertPacketById(bytes32 root_, uint64 packetId_) private {
        bytes32 root = _hcCapacitor.getRootByCount(packetId_);
        bytes32 packedRoot = root_;
        if (root != bytes32(0))
            packedRoot = keccak256(abi.encode(bytes32(0), root_));
        assertEq(root, packedRoot, "Root Invalid");
    }

    function _addPackedMessage(bytes32 packedMessage) private {
        hoax(_socket);
        _hcCapacitor.addPackedMessage(packedMessage);
    }

    function _sealPacket() private returns (bytes32 root, uint256 packetId) {
        hoax(_socket);
        (root, packetId) = _hcCapacitor.sealPacket(DEFAULT_BATCH_LENGTH);
    }
}

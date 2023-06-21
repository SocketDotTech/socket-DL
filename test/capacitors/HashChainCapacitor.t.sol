// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.20;

import "../Setup.t.sol";

contract HashChainCapacitorTest is Setup {
    address immutable _socket = address(uint160(c++));

    bytes32 immutable _message_0 = bytes32(c++);
    bytes32 immutable _message_1 = bytes32(c++);
    bytes32 immutable _message_2 = bytes32(c++);
    bytes32[] internal roots;

    HashChainCapacitor _hcCapacitor;
    HashChainDecapacitor _hcDecapacitor;

    uint256 maxPacketLength = 5;

    function setUp() external {
        initialise();

        hoax(_socketOwner);
        _hcCapacitor = new HashChainCapacitor(
            _socket,
            _socketOwner,
            maxPacketLength
        );
        _hcDecapacitor = new HashChainDecapacitor(_socketOwner);
    }

    function testSetUp() external {
        assertEq(_hcCapacitor.owner(), _socketOwner, "Owner not set");
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
        vm.expectRevert(HashChainCapacitor.InsufficentMessageLength.selector);
        _sealPacket(1);

        _addPackedMessage(_message_0);

        _sealPacket(1);
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

        _sealPacket(3);
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
        _hcCapacitor.sealPacket(maxPacketLength);
    }

    function testCapacitorRescueNativeFunds() public {
        uint256 amount = 1e18;
        hoax(_socketOwner);
        _rescueNative(
            address(_hcCapacitor),
            NATIVE_TOKEN_ADDRESS,
            _fundRescuer,
            amount
        );
    }

    function testDecapacitorRescueNativeFunds() public {
        uint256 amount = 1e18;
        hoax(_socketOwner);
        _rescueNative(
            address(_hcDecapacitor),
            NATIVE_TOKEN_ADDRESS,
            _fundRescuer,
            amount
        );
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

    function _assertPacketById(bytes32 root_, uint64 packetCount_) private {
        bytes32 root = _hcCapacitor.getRootByCount(packetCount_);
        bytes32 packedRoot = root_;
        if (root != bytes32(0))
            packedRoot = keccak256(abi.encode(bytes32(0), root_));
        assertEq(root, packedRoot, "Root Invalid");
    }

    function _addPackedMessage(bytes32 packedMessage) private {
        hoax(_socket);
        _hcCapacitor.addPackedMessage(packedMessage);
    }

    function _sealPacket(
        uint256 batchSize
    ) private returns (bytes32 root, uint256 packetId) {
        hoax(_socket);
        (root, packetId) = _hcCapacitor.sealPacket(batchSize);
    }
}

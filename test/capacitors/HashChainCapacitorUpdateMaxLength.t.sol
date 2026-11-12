// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "../../contracts/capacitors/HashChainCapacitor.sol";

// Verifies the FIXED updateMaxPacketLength: shrinking the max eagerly
// creates exactly floor(pending / newMax) packets and never bricks the
// capacitor. Run against the fixed HashChainCapacitor.sol in this project.
contract HashChainCapacitorUpdateMaxFixed is Test {
    address immutable _socket = address(0x1001);
    address immutable _owner = address(this);

    HashChainCapacitor _hc;

    function setUp() external {
        _hc = new HashChainCapacitor(_socket, _owner, 5);
    }

    function _add(uint256 n) internal {
        for (uint256 i = 0; i < n; i++) {
            vm.prank(_socket);
            _hc.addPackedMessage(bytes32(uint256(0xaaaa + i)));
        }
    }

    function testFixOnePending() external {
        _add(1); // pending = 1
        _hc.updateMaxPacketLength(3);
        // 1 / 3 = 0 packets: nothing eagerly created.
        assertEq(_hc.messagePacked(), 0, "messagePacked stays 0");
        // Capacitor still works.
        _add(2);
        assertEq(_hc.nextMessageCount(), 4);
    }

    function testFixZeroPending() external {
        _hc.updateMaxPacketLength(3); // pending = 0
        assertEq(_hc.messagePacked(), 0, "messagePacked stays 0");
        _add(3);
        assertEq(_hc.nextMessageCount(), 4);
    }

    function testFixFourPending() external {
        _add(4); // pending = 4
        _hc.updateMaxPacketLength(3);
        // 4 / 3 = 1 packet of 3: messagePacked advances 0 -> 3.
        assertEq(_hc.messagePacked(), 3, "one packet created");
        // The packet root is the hash-chain root after 3 messages.
        assertEq(_hc.getRootByCount(0), _hc.messageRoots(3));
        // Capacitor still works; the 4th message is the start of the next packet.
        _add(1);
        assertEq(_hc.nextMessageCount(), 6);
        // Adding 2 more completes a 3-message packet (messages 4,5,6).
        _add(2);
        assertEq(_hc.nextMessageCount(), 8);
    }

    function testFixSixPending() external {
        // With initial max 5, the 5th message auto-packs a packet, so only
        // 1 message is pending when we shrink. Use a fresh capacitor with
        // max 10 so all 6 messages are pending.
        HashChainCapacitor hc10 = new HashChainCapacitor(_socket, _owner, 10);
        for (uint256 i = 0; i < 6; i++) {
            vm.prank(_socket);
            hc10.addPackedMessage(bytes32(uint256(0xaaaa + i)));
        }
        assertEq(hc10.messagePacked(), 0, "nothing packed yet");
        hc10.updateMaxPacketLength(3);
        // pending = 6; 6 / 3 = 2 packets: messagePacked advances 0 -> 6.
        assertEq(hc10.messagePacked(), 6, "two packets created");
        assertEq(hc10.getRootByCount(0), hc10.messageRoots(3));
        assertEq(hc10.getRootByCount(1), hc10.messageRoots(6));
        // Capacitor still works.
        vm.prank(_socket);
        hc10.addPackedMessage(bytes32(uint256(0xffff)));
        assertEq(hc10.nextMessageCount(), 8);
    }

    function testFixShrinkAfterSomePacked() external {
        // Pack one full packet of 5 first, then shrink.
        _add(5); // auto-packs packet 0 (5 messages), messagePacked = 5
        assertEq(_hc.messagePacked(), 5);
        _add(2); // 2 more pending
        _hc.updateMaxPacketLength(3);
        // pending = (8-1) - 5 = 2; 2 / 3 = 0 packets. messagePacked stays 5.
        assertEq(_hc.messagePacked(), 5, "no extra packet");
        _add(1); // 3rd pending message -> completes a 3-message packet
        assertEq(_hc.nextMessageCount(), 9);
    }
}

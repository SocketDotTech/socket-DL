// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

contract Roles {

 bytes32 public constant RESCUE_ROLE = keccak256("RESCUE_ROLE");
 bytes32 public constant WITHDRAW_ROLE = keccak256("WITHDRAW_ROLE");
 bytes32 public constant TRIP_ROLE = keccak256("TRIP_ROLE");
 bytes32 public constant UNTRIP_ROLE = keccak256("UNTRIP_ROLE");
 bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

}
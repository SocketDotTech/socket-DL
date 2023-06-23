// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

// contains role hashes used in socket dl for various different operations

// used to rescue funds
bytes32 constant RESCUE_ROLE = keccak256("RESCUE_ROLE");
// used to withdraw fees
bytes32 constant WITHDRAW_ROLE = keccak256("WITHDRAW_ROLE");
// used to trip switchboards
bytes32 constant TRIP_ROLE = keccak256("TRIP_ROLE");
// used to un trip switchboards
bytes32 constant UN_TRIP_ROLE = keccak256("UN_TRIP_ROLE");
// used by governance
bytes32 constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
//used by executors which executes message at destination
bytes32 constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
// used by transmitters who seal and propose packets in socket
bytes32 constant TRANSMITTER_ROLE = keccak256("TRANSMITTER_ROLE");
// used by switchboard watchers who work against transmitters
bytes32 constant WATCHER_ROLE = keccak256("WATCHER_ROLE");
// used by fee updaters responsible for updating fees at switchboards, transmit manager and execution manager
bytes32 constant FEES_UPDATER_ROLE = keccak256("FEES_UPDATER_ROLE");

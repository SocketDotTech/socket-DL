// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

// contains unique identifiers which are hashes of strings, they help in making signature digest unique
// hence preventing signature replay attacks

// default switchboards
bytes32 constant TRIP_PATH_SIG_IDENTIFIER = keccak256("TRIP_PATH");
bytes32 constant TRIP_PROPOSAL_SIG_IDENTIFIER = keccak256("TRIP_PROPOSAL");
bytes32 constant TRIP_GLOBAL_SIG_IDENTIFIER = keccak256("TRIP_GLOBAL");

bytes32 constant UN_TRIP_PATH_SIG_IDENTIFIER = keccak256("UN_TRIP_PATH");
bytes32 constant UN_TRIP_GLOBAL_SIG_IDENTIFIER = keccak256("UN_TRIP_GLOBAL");

// native switchboards
bytes32 constant TRIP_NATIVE_SIG_IDENTIFIER = keccak256("TRIP_NATIVE");
bytes32 constant UN_TRIP_NATIVE_SIG_IDENTIFIER = keccak256("UN_TRIP_NATIVE");

// value threshold, price and fee updaters
bytes32 constant FEES_UPDATE_SIG_IDENTIFIER = keccak256("FEES_UPDATE");
bytes32 constant RELATIVE_NATIVE_TOKEN_PRICE_UPDATE_SIG_IDENTIFIER = keccak256(
    "RELATIVE_NATIVE_TOKEN_PRICE_UPDATE"
);
bytes32 constant MSG_VALUE_MIN_THRESHOLD_SIG_IDENTIFIER = keccak256(
    "MSG_VALUE_MIN_THRESHOLD_UPDATE"
);
bytes32 constant MSG_VALUE_MAX_THRESHOLD_SIG_IDENTIFIER = keccak256(
    "MSG_VALUE_MAX_THRESHOLD_UPDATE"
);

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./Ownable.sol";

abstract contract AccessControl is Ownable {
    // role => address => permit
    mapping(bytes32 => mapping(address => bool)) private _permits;

    event RoleGranted(bytes32 indexed role, address indexed grantee);

    event RoleRevoked(bytes32 indexed role, address indexed revokee);

    error NoPermit(bytes32 role);

    constructor(address owner_) Ownable(owner_) {}

    modifier onlyRole(bytes32 role) {
        if (!_permits[role][msg.sender]) revert NoPermit(role);
        _;
    }

    function hasRole(bytes32 role, address _address)
        external
        view
        returns (bool)
    {
        return _hasRole(role, _address);
    }

    function grantRole(bytes32 role, address grantee)
        external
        virtual
        onlyOwner
    {
        _grantRole(role, grantee);
    }

    function revokeRole(bytes32 role, address revokee)
        external
        virtual
        onlyOwner
    {
        _revokeRole(role, revokee);
    }

    function _grantRole(bytes32 role, address grantee) internal {
        _permits[role][grantee] = true;
        emit RoleGranted(role, grantee);
    }

    function _revokeRole(bytes32 role, address revokee) internal {
        _permits[role][revokee] = false;
        emit RoleRevoked(role, revokee);
    }

    function _hasRole(bytes32 role, address _address)
        internal
        view
        returns (bool)
    {
        return _permits[role][_address];
    }
}

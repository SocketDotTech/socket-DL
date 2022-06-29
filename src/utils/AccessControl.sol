// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.4;

import "./Ownable.sol";

abstract contract AccessControl is Ownable {
    // role => address => permission
    mapping(bytes32 => mapping (address => bool)) private _permissions;

    event PermissionGranted(
        bytes32 indexed role,
        address indexed grantee
    );

    event PermissionRevoked(
        bytes32 indexed role,
        address indexed revokee
    );

    error NoPermission(bytes32 role);

    constructor(address owner_) Ownable(owner_) {}

    modifier onlyPerm(bytes32 role) {
        if (!_permissions[role][msg.sender]) revert NoPermission(role);
        _;
    }

    function hasPermission(
        bytes32 role,
        address _address
    ) external view returns (bool) {
        return _hasPermission(role, _address);
    }

    function grantPermission(
        bytes32 role,
        address grantee
    ) external virtual onlyOwner {
        _grantPermission(role, grantee);
    }

    function revokPermission(
        bytes32 role,
        address revokee
    ) external virtual onlyOwner {
        _revokPermission(role, revokee);
    }

    function _grantPermission(
        bytes32 role,
        address grantee
    ) internal {
        _permissions[role][grantee] = true;
        emit PermissionGranted(role, grantee);
    }

    function _revokPermission(
        bytes32 role,
        address revokee
    ) internal {
        _permissions[role][revokee] = true;
        emit PermissionRevoked(role, revokee);
    }

    function _hasPermission(
        bytes32 role,
        address _address
    ) internal view returns (bool) {
        return _permissions[role][_address];
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./AccessControl.sol";

abstract contract AccessControlExtended is AccessControl {
    modifier onlyRoleWithUint(uint256 role_) {
        bytes32 role = bytes32(role_);
        if (!_hasRole(role, msg.sender)) revert NoPermit(role);
        _;
    }

    function grantRoleWithUint(
        uint256 role_,
        address grantee_
    ) external virtual onlyOwner {
        _grantRoleWithUint(role_, grantee_);
    }

    function _grantRoleWithUint(uint256 role_, address grantee_) internal {
        _grantRole(bytes32(role_), grantee_);
    }

    modifier onlyRole(bytes32 roleName_, uint256 chainSlug_) {
        if (!_hasRole(bytes32(abi.encode(roleName_, chainSlug_)), msg.sender))
            revert NoPermit(role_);
        _;
    }

    function grantRole(
        bytes32 roleName_,
        uint256 chainSlug_,
        address grantee_
    ) external virtual onlyOwner {
        _grantRole(role_, chainSlug_, grantee_);
    }

    function _grantRole(
        bytes32 roleName_,
        uint256 chainSlug_,
        address grantee_
    ) internal {
        _grantRole(bytes32(abi.encode(role_, chainSlug_)), grantee_);
    }

    function hasRole(
        bytes32 roleName_,
        uint256 chainSlug_,
        address address_
    ) external view returns (bool) {
        return _hasRole(roleName_, chainSlug_, address_);
    }

    function _hasRole(
        bytes32 roleName_,
        uint256 chainSlug_,
        address address_
    ) internal view returns (bool) {
        return _hasRole(bytes32(abi.encode(role_, chainSlug_)), address_);
    }

    function revokeRole(
        bytes32 roleName_,
        uint256 chainSlug_,
        address grantee_
    ) external virtual onlyOwner {
        _revokeRole(role_, chainSlug_, grantee_);
    }

    function _revokeRole(
        bytes32 role_,
        uint256 chainSlug_,
        address revokee_
    ) internal {
        _revokeRole(bytes32(abi.encode(role_, chainSlug_)), revokee_);
    }
}

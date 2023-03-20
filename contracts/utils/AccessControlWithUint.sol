// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./AccessControl.sol";

abstract contract AccessControlWithUint is AccessControl {
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

    function revokeRoleWithUint(
        uint256 role_,
        address revokee_
    ) external virtual onlyOwner {
        _revokeRoleWithUint(role_, revokee_);
    }

    function hasRoleWithUint(
        uint256 role_,
        address address_
    ) external view returns (bool) {
        return _hasRoleWithUint(role_, address_);
    }

    function _hasRoleWithUint(
        uint256 role_,
        address address_
    ) internal view returns (bool) {
        return _hasRole(bytes32(role_), address_);
    }

    function _grantRoleWithUint(uint256 role_, address grantee_) internal {
        _grantRole(bytes32(role_), grantee_);
    }

    function _revokeRoleWithUint(uint256 role_, address revokee_) internal {
        _revokeRole(bytes32(role_), revokee_);
    }
}

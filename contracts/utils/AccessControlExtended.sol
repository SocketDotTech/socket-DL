// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./AccessControl.sol";

/**
 * @title AccessControlExtended
 * @dev This contract extends the functionality of the AccessControl contract by adding
 * the ability to grant and revoke roles based on a combination of role name and a chain slug.
 * It also provides batch operations for granting and revoking roles.
 */
contract AccessControlExtended is AccessControl {
    /**
     * @dev Constructor that sets the owner of the contract.
     */
    constructor(address owner_) AccessControl(owner_) {}

    /**
     * @dev Checks if an address has the role.
     * @param roleName_ The name of the role.
     * @param chainSlug_ The chain slug associated with the role.
     * @param address_ The address to be granted the role.
     */
    function _checkRoleWithSlug(
        bytes32 roleName_,
        uint256 chainSlug_,
        address address_
    ) internal virtual {
        bytes32 roleHash = keccak256(abi.encode(roleName_, chainSlug_));
        if (!_hasRole(roleHash, address_)) revert NoPermit(roleHash);
    }

    /**
     * @dev Grants a role to an address based on the role name and chain slug.
     * @param roleName_ The name of the role.
     * @param chainSlug_ The chain slug associated with the role.
     * @param grantee_ The address to be granted the role.
     */
    function grantRoleWithSlug(
        bytes32 roleName_,
        uint32 chainSlug_,
        address grantee_
    ) external virtual onlyOwner {
        _grantRoleWithSlug(roleName_, chainSlug_, grantee_);
    }

    /**
     * @dev Grants multiple roles to multiple addresses in batch.
     * @param roleNames_ The names of the roles to grant.
     * @param grantees_ The addresses to be granted the roles.
     */
    function grantBatchRoleWithSlug(
        bytes32[] calldata roleNames_,
        address[] calldata grantees_
    ) external virtual onlyOwner {
        require(roleNames_.length == grantees_.length);
        for (uint256 index = 0; index < roleNames_.length; index++)
            _grantRole(roleNames_[index], grantees_[index]);
    }

    /**
     * @dev Revokes multiple roles from multiple addresses in batch.
     * @param roleNames_ The names of the roles to revoke.
     * @param grantees_ The addresses to be revoked the roles.
     */
    function revokeBatchRoleWithSlug(
        bytes32[] calldata roleNames_,
        address[] calldata grantees_
    ) external virtual onlyOwner {
        require(roleNames_.length == grantees_.length);
        for (uint256 index = 0; index < roleNames_.length; index++)
            _revokeRole(roleNames_[index], grantees_[index]);
    }

    function _grantRoleWithSlug(
        bytes32 roleName_,
        uint32 chainSlug_,
        address grantee_
    ) internal {
        _grantRole(keccak256(abi.encode(roleName_, chainSlug_)), grantee_);
    }

    /**
     * @dev Checks if an address has a role based on the role name and chain slug.
     * @param roleName_ The name of the role.
     * @param chainSlug_ The chain slug associated with the role.
     * @param address_ The address to check for the role.
     * @return A boolean indicating whether the address has the specified role.
     */
    function hasRoleWithSlug(
        bytes32 roleName_,
        uint32 chainSlug_,
        address address_
    ) external view returns (bool) {
        return _hasRoleWithSlug(roleName_, chainSlug_, address_);
    }

    function _hasRoleWithSlug(
        bytes32 roleName_,
        uint32 chainSlug_,
        address address_
    ) internal view returns (bool) {
        return _hasRole(keccak256(abi.encode(roleName_, chainSlug_)), address_);
    }

    /**
     * @dev Revokes roles from an address
     * @param roleName_ The names of the roles to revoke.
     * @param chainSlug_ The chain slug associated with the role.
     * @param grantee_ The addresses to be revoked the roles.
     */
    function revokeRoleWithSlug(
        bytes32 roleName_,
        uint32 chainSlug_,
        address grantee_
    ) external virtual onlyOwner {
        _revokeRoleWithSlug(roleName_, chainSlug_, grantee_);
    }

    function _revokeRoleWithSlug(
        bytes32 roleName_,
        uint32 chainSlug_,
        address revokee_
    ) internal {
        _revokeRole(keccak256(abi.encode(roleName_, chainSlug_)), revokee_);
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

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
     * @dev thrown when array lengths are not equal
     */
    error UnequalArrayLengths();

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
     * @param slugs_ The slugs for chain specific roles. For roles which are not chain-specific, we can use slug = 0
     * @param grantees_ The addresses to be granted the roles.
     */
    function grantBatchRole(
        bytes32[] calldata roleNames_,
        uint32[] calldata slugs_,
        address[] calldata grantees_
    ) external virtual onlyOwner {
        if (
            roleNames_.length != grantees_.length ||
            roleNames_.length != slugs_.length
        ) revert UnequalArrayLengths();
        uint256 totalRoles = roleNames_.length;
        for (uint256 index = 0; index < totalRoles; ) {
            if (slugs_[index] > 0)
                _grantRoleWithSlug(
                    roleNames_[index],
                    slugs_[index],
                    grantees_[index]
                );
            else _grantRole(roleNames_[index], grantees_[index]);

            // inputs are controlled by owner
            unchecked {
                ++index;
            }
        }
    }

    /**
     * @dev Revokes multiple roles from multiple addresses in batch.
     * @param roleNames_ The names of the roles to revoke.
     * @param slugs_ The slugs for chain specific roles. For roles which are not chain-specific, we can use slug = 0
     * @param grantees_ The addresses to be revoked the roles.
     */
    function revokeBatchRole(
        bytes32[] calldata roleNames_,
        uint32[] calldata slugs_,
        address[] calldata grantees_
    ) external virtual onlyOwner {
        if (
            roleNames_.length != grantees_.length ||
            roleNames_.length != slugs_.length
        ) revert UnequalArrayLengths();
        uint256 totalRoles = roleNames_.length;
        for (uint256 index = 0; index < totalRoles; ) {
            if (slugs_[index] > 0)
                _revokeRoleWithSlug(
                    roleNames_[index],
                    slugs_[index],
                    grantees_[index]
                );
            else _revokeRole(roleNames_[index], grantees_[index]);

            // inputs are controlled by owner
            unchecked {
                ++index;
            }
        }
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

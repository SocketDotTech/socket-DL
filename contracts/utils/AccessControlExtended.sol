// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./AccessControl.sol";

contract AccessControlExtended is AccessControl {
    modifier onlyRoleWithChainSlug(
        string memory roleName_,
        uint256 chainSlug_
    ) {
        bytes32 role = keccak256(abi.encode(roleName_, chainSlug_));
        if (!_hasRole(role, msg.sender)) revert NoPermit(role);
        _;
    }

    constructor(address owner_) AccessControl(owner_) {}

    function grantRole(
        string memory roleName_,
        uint256 chainSlug_,
        address grantee_
    ) external virtual onlyOwner {
        _grantRole(roleName_, chainSlug_, grantee_);
    }

    function grantBatchRole(
        bytes32[] calldata roleNames_,
        address[] calldata grantees_
    ) external virtual onlyOwner {
        require(roleNames_.length == grantees_.length);
        for (uint256 index = 0; index < roleNames_.length; index++)
            _grantRole(roleNames_[index], grantees_[index]);
    }

    function revokeBatchRole(
        bytes32[] calldata roleNames_,
        address[] calldata grantees_
    ) external virtual onlyOwner {
        require(roleNames_.length == grantees_.length);
        for (uint256 index = 0; index < roleNames_.length; index++)
            _revokeRole(roleNames_[index], grantees_[index]);
    }

    function _grantRole(
        string memory roleName_,
        uint256 chainSlug_,
        address grantee_
    ) internal {
        _grantRole(keccak256(abi.encode(roleName_, chainSlug_)), grantee_);
    }

    function hasRole(
        string memory roleName_,
        uint256 chainSlug_,
        address address_
    ) external view returns (bool) {
        return _hasRole(roleName_, chainSlug_, address_);
    }

    function _hasRole(
        string memory roleName_,
        uint256 chainSlug_,
        address address_
    ) internal view returns (bool) {
        return _hasRole(keccak256(abi.encode(roleName_, chainSlug_)), address_);
    }

    function revokeRole(
        string memory roleName_,
        uint256 chainSlug_,
        address grantee_
    ) external virtual onlyOwner {
        _revokeRole(roleName_, chainSlug_, grantee_);
    }

    function _revokeRole(
        string memory roleName_,
        uint256 chainSlug_,
        address revokee_
    ) internal {
        _revokeRole(keccak256(abi.encode(roleName_, chainSlug_)), revokee_);
    }
}

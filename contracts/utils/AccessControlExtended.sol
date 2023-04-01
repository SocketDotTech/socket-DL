// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./AccessControl.sol";

contract AccessControlExtended is AccessControl {
    modifier onlyRoleWithChainSlug(bytes32 roleName_, uint256 chainSlug_) {
        if (!_hasRole(bytes32(abi.encode(roleName_, chainSlug_)), msg.sender))
            revert NoPermit(roleName_);
        _;
    }

    constructor(address owner_) AccessControl(owner_) {}

    function grantRole(
        bytes32 roleName_,
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

    function _grantRole(
        bytes32 roleName_,
        uint256 chainSlug_,
        address grantee_
    ) internal {
        _grantRole(keccak256(abi.encode(roleName_, chainSlug_)), grantee_);
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
        return _hasRole(bytes32(abi.encode(roleName_, chainSlug_)), address_);
    }

    function revokeRole(
        bytes32 roleName_,
        uint256 chainSlug_,
        address grantee_
    ) external virtual onlyOwner {
        _revokeRole(roleName_, chainSlug_, grantee_);
    }

    function _revokeRole(
        bytes32 roleName_,
        uint256 chainSlug_,
        address revokee_
    ) internal {
        _revokeRole(bytes32(abi.encode(roleName_, chainSlug_)), revokee_);
    }
}

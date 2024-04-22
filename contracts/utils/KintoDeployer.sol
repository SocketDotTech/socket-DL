// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./Ownable.sol";

/**
 * @title KintoDeployer
 * @dev Convenience contract for deploying contracts on Kinto using `CREATE2`
 * and nominating a new address to be the owner.
 */
contract KintoDeployer {
    event ContractDeployed(address indexed addr);

    /**
     * @dev Deploys a contract using `CREATE2` and nominates a new address
     * for owner (if set).
     *
     * The bytecode for a contract can be obtained from Solidity with
     * `type(contractName).creationCode`.
     *
     * @param nominee address to be set as nominee (if set)
     * @param bytecode of the contract to deploy
     * @param salt to use for the calculation
     */
    function deploy(
        address nominee,
        bytes memory bytecode,
        bytes32 salt
    ) external payable returns (address) {
        address addr;
        // deploy the contract using `CREATE2`
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        require(addr != address(0), "Failed to deploy contract");

        // nominate address if contract is Ownable
        try Ownable(addr).owner() returns (address owner_) {
            if (owner_ == address(this) && nominee != address(0)) {
                Ownable(addr).nominateOwner(nominee);
            }
        } catch {}
        emit ContractDeployed(addr);
        return addr;
    }
}

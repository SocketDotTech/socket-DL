// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/Socket.sol";
import "../src/Notary/AdminNotary.sol";
import "../src/accumulators/SingleAccum.sol";
import "../src/deaccumulators/SingleDeaccum.sol";
import "../src/utils/SignatureVerifier.sol";
import "../src/utils/Hasher.sol";
import "./HelperConfig.sol";

contract DeploySocket is Script {
    bytes32 private constant _ATTESTER_ROLE = keccak256("ATTESTER_ROLE");

    function run() external {
        HelperConfig helperConfig = new HelperConfig();

        (uint256 destChainId, address signer, , ) = helperConfig
            .activeNetworkConfig();

        vm.startBroadcast();

        Hasher hasher__ = new Hasher();

        // deploy socket
        Socket socket__ = new Socket(block.chainid, address(hasher__));
        SignatureVerifier sigVerifier__ = new SignatureVerifier();
        Notary notary__ = new Notary(block.chainid, address(sigVerifier__));

        socket__.setNotary(address(notary__));

        // deploy accumulators
        new SingleAccum(address(socket__), address(notary__));

        // deploy deaccumulators
        new SingleDeaccum();

        notary__.grantRole(_ATTESTER_ROLE, signer);
        notary__.grantSignerRole(destChainId, signer);

        vm.stopBroadcast();
    }
}

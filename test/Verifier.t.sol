// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./Setup.sol";

contract VerifierTest is Setup {
    address DUMMY_MANAGER = address(1);
    address DUMMY_SOCKET = address(2);
    address DUMMY_PAUSER = address(4);
    uint256 chainId = 1;
    uint256 destChainId = 2;

    uint256 timeoutInSeconds = 100;

    Verifier verifier;
    ChainContext cc;

    function setUp() public {
        uint256[] memory attesters = new uint256[](2);
        attesters[0] = _attesterPrivateKey;
        attesters[1] = _altAttesterPrivateKey;

        (cc.sigVerifier__, cc.notary__) = _deployNotary(chainId, _socketOwner);

        cc.verifier__ = new Verifier(
            DUMMY_SOCKET,
            DUMMY_MANAGER,
            address(cc.notary__),
            timeoutInSeconds
        );

        _initVerifier(cc, destChainId);
    }

    function testDeployment() public {
        assertEq(cc.verifier__.manager(), DUMMY_MANAGER);
        assertEq(cc.verifier__.socket(), DUMMY_SOCKET);
        bool isActive = cc.verifier__.isChainActive(chainId);
        assertTrue(isActive);
    }

    function testPausing() public {
        bool isPauser = cc.verifier__.isPauser(DUMMY_PAUSER, chainId);
        assertTrue(isPauser);

        vm.prank(DUMMY_SOCKET);
        (bool valid, ) = cc.verifier__.verifyRoot(address(0), chainId, 0);
        assertTrue(valid);

        vm.prank(DUMMY_PAUSER);
        cc.verifier__.pause(chainId);

        assertFalse(cc.verifier__.isChainActive(chainId));
    }

    function testVerifyAfterpause() public {
        bool isPauser = cc.verifier__.isPauser(DUMMY_PAUSER, chainId);
        assertTrue(isPauser);

        vm.prank(DUMMY_SOCKET);
        (bool valid, ) = cc.verifier__.verifyRoot(address(0), chainId, 0);
        assertTrue(valid);

        vm.prank(DUMMY_PAUSER);
        cc.verifier__.pause(chainId);

        (valid, ) = cc.verifier__.verifyRoot(address(0), chainId, 0);
        assertFalse(valid);
    }
}

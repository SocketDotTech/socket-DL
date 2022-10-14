// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./Setup.t.sol";

contract VerifierTest is Setup {
    uint256 chainSlug = 1;
    uint256 remoteChainSlug = 2;
    uint256 timeoutInSeconds = 100;
    bytes32 integrationType = keccak256(abi.encode("INTEGRATION_TYPE"));

    Verifier verifier__;
    ChainContext cc;

    function setUp() public {
        cc.chainSlug = chainSlug;
        (cc.sigVerifier__, cc.notary__) = _deployNotary(
            chainSlug,
            _socketOwner
        );

        hoax(_socketOwner);
        verifier__ = new Verifier(
            _socketOwner,
            address(cc.notary__),
            address(cc.socket__),
            timeoutInSeconds,
            integrationType
        );
    }

    function testDeployment() public {
        assertEq(verifier__.owner(), _socketOwner);

        assertEq(address(verifier__.notary()), address(cc.notary__));
        assertEq(address(verifier__.socket()), address(cc.socket__));

        assertEq(verifier__.timeoutInSeconds(), timeoutInSeconds);
        assertEq(verifier__.integrationType(), integrationType);
    }

    function testSetNotary() external {
        address newNotary = address(9);

        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        verifier__.setNotary(newNotary);

        hoax(_socketOwner);
        verifier__.setNotary(newNotary);
        assertEq(address(verifier__.notary()), newNotary);
    }

    function testSetSocket() external {
        address newSocket = address(9);

        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        verifier__.setSocket(newSocket);

        hoax(_socketOwner);
        verifier__.setSocket(newSocket);
        assertEq(address(verifier__.socket()), newSocket);
    }

    function testVerifyCommitmentNotProposed() public {
        // less attestations
        vm.mockCall(
            address(cc.notary__),
            abi.encodeWithSelector(INotary.getPacketDetails.selector),
            abi.encode(0, 1, 0, bytes32(0))
        );

        // without timeout
        (bool valid, ) = verifier__.verifyPacket(1, integrationType);
        assertFalse(valid);
    }

    function testVerifyCommitmentFastPath() public {
        // before timeout
        // less attestations
        vm.mockCall(
            address(cc.notary__),
            abi.encodeWithSelector(INotary.getPacketDetails.selector),
            abi.encode(1, 1, 1, bytes32(0))
        );
        (bool valid, ) = verifier__.verifyPacket(1, integrationType);
        assertFalse(valid);

        // full attestations
        vm.mockCall(
            address(cc.notary__),
            abi.encodeWithSelector(INotary.getPacketDetails.selector),
            abi.encode(1, 1, 0, bytes32(0))
        );
        (valid, ) = verifier__.verifyPacket(1, integrationType);
        assertTrue(valid);

        // after timeout
        // less attestations
        vm.mockCall(
            address(cc.notary__),
            abi.encodeWithSelector(INotary.getPacketDetails.selector),
            abi.encode(1, 1, 1, bytes32(0))
        );
        vm.warp(timeoutInSeconds + 20);
        (valid, ) = verifier__.verifyPacket(1, integrationType);
        assertTrue(valid);
    }

    function testVerifyCommitmentSlowPath() public {
        bytes32 slow = keccak256(abi.encode("SLOW_INTEGRATION_TYPE"));
        // before timeout
        vm.mockCall(
            address(cc.notary__),
            abi.encodeWithSelector(INotary.getPacketDetails.selector),
            abi.encode(1, 1, 1, bytes32(0))
        );
        (bool valid, ) = verifier__.verifyPacket(1, slow);
        assertFalse(valid);

        // full attestations
        vm.mockCall(
            address(cc.notary__),
            abi.encodeWithSelector(INotary.getPacketDetails.selector),
            abi.encode(1, 1, 0, bytes32(0))
        );
        (valid, ) = verifier__.verifyPacket(1, slow);
        assertFalse(valid);

        // after timeout
        vm.mockCall(
            address(cc.notary__),
            abi.encodeWithSelector(INotary.getPacketDetails.selector),
            abi.encode(1, 1, 1, bytes32(0))
        );
        vm.warp(timeoutInSeconds + 20);
        (valid, ) = verifier__.verifyPacket(1, slow);
        assertTrue(valid);
    }
}

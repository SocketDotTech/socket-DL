// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./Setup.t.sol";

contract VerifierTest is Setup {
    address _notAPauser = address(10);

    uint256 chainId = 1;
    uint256 destChainId = 2;
    uint256 anotherDestChainId = 3;
    uint256 timeoutInSeconds = 100;

    Verifier verifier;
    ChainContext cc;

    function setUp() public {
        cc.chainId = chainId;
        (cc.sigVerifier__, cc.notary__) = _deployNotary(chainId, _socketOwner);

        hoax(_socketOwner);
        cc.verifier__ = new Verifier(
            _socketOwner,
            address(cc.notary__),
            timeoutInSeconds
        );
    }

    function testDeployment() public {
        assertEq(cc.verifier__.owner(), _socketOwner);
        assertEq(address(cc.verifier__.notary()), address(cc.notary__));
        assertEq(cc.verifier__.timeoutInSeconds(), timeoutInSeconds);
    }

    function testSetNotary() external {
        address newNotary = address(9);

        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        cc.verifier__.setNotary(newNotary);

        hoax(_socketOwner);
        cc.verifier__.setNotary(newNotary);
        assertEq(address(cc.verifier__.notary()), newNotary);
    }

    function testVerifyCommitment() public {
        vm.mockCall(
            address(cc.notary__),
            abi.encodeWithSelector(INotary.getPacketDetails.selector),
            abi.encode(true, 1, bytes32(0))
        );

        (bool valid, ) = cc.verifier__.verifyCommitment(
            address(0),
            destChainId,
            0
        );
        assertTrue(valid);

        vm.mockCall(
            address(cc.notary__),
            abi.encodeWithSelector(INotary.getPacketDetails.selector),
            abi.encode(false, 1, bytes32(0))
        );

        (valid, ) = cc.verifier__.verifyCommitment(address(0), destChainId, 0);
        assertFalse(valid);

        vm.warp(1000);
        (valid, ) = cc.verifier__.verifyCommitment(address(0), destChainId, 0);
        assertTrue(valid);
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "../contracts/utils/MultiSigWrapper.sol";
import "../contracts/mocks/MockSafe.sol";

contract MultiSigWrapperTestHelper is MultiSigWrapper {
    constructor(address owner_, address safe_) MultiSigWrapper(owner_, safe_) {}

    function publicGetSignatures(
        bytes32 txHash_
    ) external view returns (bytes memory) {
        return _getSignatures(txHash_);
    }

    function getOwners(
        bytes32 txHash_
    ) external view returns (address[] memory) {
        return owners[txHash_];
    }
}

contract MultiSigWrapperTest is Test {
    MultiSigWrapperTestHelper public multiSigWrapper;
    MockSafe public mockSafe;

    uint256 internal c = 1000;
    address public owner = address(uint160(c++));
    address public addr1 = address(uint160(c++));
    address public addr2 = address(uint160(c++));
    address public addr3 = address(uint160(c++));

    function setUp() public {
        mockSafe = new MockSafe();
        multiSigWrapper = new MultiSigWrapperTestHelper(
            owner,
            address(mockSafe)
        );
    }

    function testInitialize() public {
        assertEq(address(multiSigWrapper.safe()), address(mockSafe));
        assertTrue(multiSigWrapper.hasRole(RESCUE_ROLE, owner));
    }

    function testStoreOrRelaySignaturesSingleSig() public {
        // Setting threshold to 1 in mockSafe
        mockSafe.setThreshold(1);

        // Creating test data
        address to = address(0xdef);
        uint256 value = 1 ether;
        bytes memory data = "0x1234";
        bytes memory signature = "0x5678";

        // Store or relay signatures
        multiSigWrapper.storeOrRelaySignatures(
            owner,
            to,
            mockSafe.nonce(),
            value,
            data,
            signature
        );

        // Verify that the transaction was relayed
        (
            address relayedTo,
            uint256 relayedValue,
            bytes memory relayedData
        ) = mockSafe.getLastTransaction();
        assertEq(relayedTo, to);
        assertEq(relayedValue, value);
        assertEq(keccak256(relayedData), keccak256(data));
    }

    function testStoreOrRelaySignaturesWithOverrides() public {
        // Setting threshold to 1 in mockSafe
        mockSafe.setThreshold(1);

        // Creating test data
        address to = address(0xdef);
        uint256 value = 1 ether;
        Enum.Operation operation = Enum.Operation.Call;
        MultiSigWrapper.GasParams memory gasParams = MultiSigWrapper.GasParams(
            100000,
            10000,
            1 gwei,
            address(0),
            payable(address(0))
        );
        bytes memory data = "0x1234";
        bytes memory signature = "0x5678";

        // Store or relay signatures with overrides
        multiSigWrapper.storeOrRelaySignaturesWithOverrides(
            owner,
            to,
            mockSafe.nonce(),
            value,
            operation,
            gasParams,
            data,
            signature
        );

        // Verify that the transaction was relayed
        (
            address relayedTo,
            uint256 relayedValue,
            bytes memory relayedData
        ) = mockSafe.getLastTransaction();
        assertEq(relayedTo, to);
        assertEq(relayedValue, value);
        assertEq(keccak256(relayedData), keccak256(data));
    }

    function testStoreOrRelaySignaturesForBigThreshold() public {
        // Setting threshold to 3 in mockSafe
        mockSafe.setThreshold(3);

        // Creating test data
        address to = address(0xdef);
        uint256 value = 1 ether;
        bytes memory data = "0x1234";
        bytes memory signature1 = "0x4";
        bytes memory signature2 = "0x5";
        bytes memory signature3 = "0x6";

        bytes32 txHash = keccak256(
            abi.encode(
                to,
                value,
                data,
                Enum.Operation.Call,
                mockSafe.nonce(),
                0
            )
        );

        // Store first signature
        multiSigWrapper.storeOrRelaySignatures(
            addr1,
            to,
            mockSafe.nonce(),
            value,
            data,
            signature1
        );
        bytes memory signature = multiSigWrapper.signatures(txHash, addr1);
        // address sigOwner = multiSigWrapper.owners(txHash, 1);
        // assertEq(owner, addr1);
        assertEq(signature, signature1);

        // Store second signature
        multiSigWrapper.storeOrRelaySignatures(
            addr2,
            to,
            mockSafe.nonce(),
            value,
            data,
            signature2
        );
        signature = multiSigWrapper.signatures(txHash, addr2);
        // sigOwner = multiSigWrapper.owners(txHash, 2);
        // assertEq(owner, addr2);
        assertEq(signature, signature2);

        // Store third signature
        multiSigWrapper.storeOrRelaySignatures(
            addr3,
            to,
            mockSafe.nonce(),
            value,
            data,
            signature3
        );
        signature = multiSigWrapper.signatures(txHash, addr3);
        // sigOwner = multiSigWrapper.owners(txHash, 3);
        // assertEq(owner, addr3);
        assertEq(signature, signature3);

        bytes memory combinedSign = multiSigWrapper.publicGetSignatures(txHash);
        bytes memory expectedSign = abi.encodePacked(signature1, signature2);
        expectedSign = abi.encodePacked(expectedSign, signature3);
        assertEq(combinedSign, expectedSign);

        // Verify that the transaction was relayed
        (
            address relayedTo,
            uint256 relayedValue,
            bytes memory relayedData
        ) = mockSafe.getLastTransaction();
        assertEq(relayedTo, to);
        assertEq(relayedValue, value);
        assertEq(keccak256(relayedData), keccak256(data));
    }

    function testStoreOrRelaySignaturesForUnorderedAddresses() public {
        // Setting threshold to 3 in mockSafe
        mockSafe.setThreshold(3);

        // Creating test data
        address to = address(0xdef);
        uint256 value = 1 ether;
        bytes memory data = "0x1234";
        bytes memory signature1 = "0x4";
        bytes memory signature2 = "0x5";
        bytes memory signature3 = "0x6";

        bytes32 txHash = keccak256(
            abi.encode(
                to,
                value,
                data,
                Enum.Operation.Call,
                mockSafe.nonce(),
                0
            )
        );

        // Store third signature
        multiSigWrapper.storeOrRelaySignatures(
            addr3,
            to,
            mockSafe.nonce(),
            value,
            data,
            signature3
        );
        bytes memory signature = multiSigWrapper.signatures(txHash, addr3);
        assertEq(signature, signature3);

        // Store second signature
        multiSigWrapper.storeOrRelaySignatures(
            addr2,
            to,
            mockSafe.nonce(),
            value,
            data,
            signature2
        );
        signature = multiSigWrapper.signatures(txHash, addr2);
        assertEq(signature, signature2);

        // Store first signature
        multiSigWrapper.storeOrRelaySignatures(
            addr1,
            to,
            mockSafe.nonce(),
            value,
            data,
            signature1
        );
        signature = multiSigWrapper.signatures(txHash, addr1);
        assertEq(signature, signature1);

        bytes memory combinedSign = multiSigWrapper.publicGetSignatures(txHash);
        bytes memory expectedSign = abi.encodePacked(signature1, signature2);
        expectedSign = abi.encodePacked(expectedSign, signature3);
        assertEq(combinedSign, expectedSign);

        // Verify that the transaction was relayed
        (
            address relayedTo,
            uint256 relayedValue,
            bytes memory relayedData
        ) = mockSafe.getLastTransaction();
        assertEq(relayedTo, to);
        assertEq(relayedValue, value);
        assertEq(keccak256(relayedData), keccak256(data));
    }

    function testRescueFunds() public {
        // Mock RescueFundsLib call
        address token = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        address rescueTo = addr1;
        uint256 amount = 1000;
        uint256 initialBal = rescueTo.balance;

        deal(address(multiSigWrapper), amount);

        // Call rescueFunds
        hoax(owner);
        multiSigWrapper.rescueFunds(token, rescueTo, amount);

        assertEq(rescueTo.balance, initialBal + amount);
    }

    function testUpdateSafe() public {
        // Update the safe contract
        address newSafe = address(0xdef);

        vm.expectRevert();
        multiSigWrapper.updateSafe(newSafe);

        hoax(owner);
        multiSigWrapper.updateSafe(newSafe);

        // Verify that the safe contract was updated
        assertEq(address(multiSigWrapper.safe()), newSafe);
    }
}

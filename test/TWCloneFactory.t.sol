// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "../src/TWCloneFactory.sol";
import {LibClone} from "@solady/utils/LibClone.sol";
import "forge-std/Test.sol";

contract MockImplementation {

    uint256 public value;

    function initialize(uint256 _value) public {
        value = _value;
    }

}

contract TWCloneFactoryTest is Test {

    TWCloneFactory factory;
    MockImplementation implementation;

    uint256 chainId1 = 1;
    uint256 chainId2 = 2;

    function setUp() public {
        factory = new TWCloneFactory();
        implementation = new MockImplementation();
    }

    // Test case 1: Cross chain deployment on - same address on two chains
    function testCrossChainDeploymentOnSameAddress() public {
        // Set up the salt with allowCrossChainDeployment = true, encodeDataIntoSalt = false
        // salt[0] == hex"01", salt[1] == hex"00"
        bytes32 salt = bytes32(abi.encodePacked(hex"01", hex"00", bytes30(0)));
        bytes memory data = "";

        // Save the current state
        uint256 snapshotId = vm.snapshot();

        // Set chain ID to chainId1 and deploy
        vm.chainId(chainId1);
        address proxy1 = factory.deployProxyByImplementation(address(implementation), data, salt);

        // Revert to the snapshot to reset the state
        vm.revertTo(snapshotId);

        // Set chain ID to chainId2 and deploy
        vm.chainId(chainId2);
        address proxy2 = factory.deployProxyByImplementation(address(implementation), data, salt);

        // Check that the proxies are the same
        assertEq(proxy1, proxy2, "Proxies should be the same on different chains when cross chain deployment is on");
    }

    // Test case 2: Cross chain deployment off - different address on two chains
    function testCrossChainDeploymentOffDifferentAddress() public {
        // Set up the salt with allowCrossChainDeployment = false, encodeDataIntoSalt = false
        // salt[0] == hex"00", salt[1] == hex"00"
        bytes32 salt = bytes32(abi.encodePacked(hex"00", hex"00", bytes30(0)));
        bytes memory data = "";

        // Save the current state
        uint256 snapshotId = vm.snapshot();

        // Set chain ID to chainId1 and deploy
        vm.chainId(chainId1);
        address proxy1 = factory.deployProxyByImplementation(address(implementation), data, salt);

        // Revert to the snapshot to reset the state
        vm.revertTo(snapshotId);

        // Set chain ID to chainId2 and deploy
        vm.chainId(chainId2);
        address proxy2 = factory.deployProxyByImplementation(address(implementation), data, salt);

        // Check that the proxies are different
        assertNotEq(
            proxy1, proxy2, "Proxies should be different on different chains when cross chain deployment is off"
        );
    }

    // Test case 3: Not encodeDataIntoSalt - same address with different init data
    function testNotEncodeDataIntoSaltSameAddress() public {
        // Set up the salt with allowCrossChainDeployment = true, encodeDataIntoSalt = false
        // salt[0] == hex"01", salt[1] == hex"00"
        bytes32 salt = bytes32(abi.encodePacked(hex"01", hex"00", bytes30(0)));

        // Save the current state
        uint256 snapshotId = vm.snapshot();

        // Deploy with data1
        vm.chainId(chainId1);
        bytes memory data1 = abi.encodeWithSignature("initialize(uint256)", 42);
        address proxy1 = factory.deployProxyByImplementation(address(implementation), data1, salt);

        // Revert to the snapshot to reset the state
        vm.revertTo(snapshotId);

        // Deploy with data2
        vm.chainId(chainId2);
        bytes memory data2 = abi.encodeWithSignature("initialize(uint256)", 100);
        address proxy2 = factory.deployProxyByImplementation(address(implementation), data2, salt);

        // Check that the proxies are the same
        assertEq(proxy1, proxy2, "Proxies should be the same when encodeDataIntoSalt is off");
    }

    // Test case 4: Encode Data into salt - different address with different init data
    function testEncodeDataIntoSaltDifferentAddress() public {
        // Set up the salt with allowCrossChainDeployment = true, encodeDataIntoSalt = true
        // salt[0] == hex"01", salt[1] == hex"01"
        bytes32 salt = bytes32(abi.encodePacked(hex"01", hex"01", bytes30(0)));

        // Deploy with data1
        bytes memory data1 = abi.encodeWithSignature("initialize(uint256)", 42);
        address proxy1 = factory.deployProxyByImplementation(address(implementation), data1, salt);

        // Deploy with data2
        bytes memory data2 = abi.encodeWithSignature("initialize(uint256)", 100);
        address proxy2 = factory.deployProxyByImplementation(address(implementation), data2, salt);

        // Check that the proxies are different
        assertNotEq(proxy1, proxy2, "Proxies should be different when encodeDataIntoSalt is on");

        // Verify that both initializations took effect independently
        MockImplementation proxyImpl1 = MockImplementation(proxy1);
        uint256 value1 = proxyImpl1.value();
        assertEq(value1, 42, "Value should be initialized to 42");

        MockImplementation proxyImpl2 = MockImplementation(proxy2);
        uint256 value2 = proxyImpl2.value();
        assertEq(value2, 100, "Value should be initialized to 100");
    }

}

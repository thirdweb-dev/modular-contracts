// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/forge-std/src/console.sol";

import {Test} from "forge-std/Test.sol";

// Target contract

import {ModularCore} from "src/ModularCore.sol";
import {ModularModule} from "src/ModularModule.sol";
import {ERC721Core} from "src/core/token/ERC721Core.sol";

import {IModularCore} from "src/interface/IModularCore.sol";
import {IModuleConfig} from "src/interface/IModuleConfig.sol";
import {DelayedRevealBatchMetadataERC721} from "src/module/token/metadata/DelayedRevealBatchMetadataERC721.sol";

contract DelayedRevealExt is DelayedRevealBatchMetadataERC721 {}

contract DelayedRevealBatchMetadataERC721Test is Test {

    ERC721Core public core;

    DelayedRevealExt public moduleImplementation;

    address public owner = address(0x1);
    address public permissionedActor = address(0x2);
    address public unpermissionedActor = address(0x3);

    function setUp() public {
        address[] memory modules;
        bytes[] memory moduleData;

        core = new ERC721Core("test", "TEST", "", owner, modules, moduleData);
        moduleImplementation = new DelayedRevealExt();

        // install module
        vm.prank(owner);
        core.installModule(address(moduleImplementation), "");
    }

    /*///////////////////////////////////////////////////////////////
                        Helper functions
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice         Encrypt/decrypt data on chain.
     *  @dev            Encrypt/decrypt given `data` with `key`. Uses inline assembly.
     *                  See: https://ethereum.stackexchange.com/questions/69825/decrypt-message-on-chain
     */
    function _encryptDecrypt(bytes memory data, bytes memory key) internal pure returns (bytes memory result) {
        // Store data length on stack for later use
        uint256 length = data.length;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Set result to free memory pointer
            result := mload(0x40)
            // Increase free memory pointer by lenght + 32
            mstore(0x40, add(add(result, length), 32))
            // Set result length
            mstore(result, length)
        }

        // Iterate over the data stepping by 32 bytes
        for (uint256 i = 0; i < length; i += 32) {
            // Generate hash of the key and offset
            bytes32 hash = keccak256(abi.encodePacked(key, i));

            bytes32 chunk;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                // Read 32-bytes data chunk
                chunk := mload(add(data, add(i, 32)))
            }
            // XOR the chunk with hash
            chunk ^= hash;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                // Write 32-byte encrypted chunk
                mstore(add(result, add(i, 32)), chunk)
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                        Unit tests: `uploadMetadata`
    //////////////////////////////////////////////////////////////*/

    function test_state_uploadMetadata() public {
        vm.prank(owner);
        DelayedRevealExt(address(core)).uploadMetadata(100, "ipfs://base/", "");

        // read state from core
        assertEq(core.tokenURI(1), "ipfs://base/1");
        assertEq(core.tokenURI(99), "ipfs://base/99");

        // upload another batch
        vm.prank(owner);
        DelayedRevealExt(address(core)).uploadMetadata(100, "ipfs://base2/", "");

        // read state from core
        assertEq(core.tokenURI(1), "ipfs://base/1");
        assertEq(core.tokenURI(99), "ipfs://base/99");
        assertEq(core.tokenURI(100), "ipfs://base2/100");
        assertEq(core.tokenURI(199), "ipfs://base2/199");
    }

    function test_state_uploadMetadata_encrypted() public {
        string memory originalURI = "ipfs://original/";
        string memory tempURI = "ipfs://temp/";
        bytes memory encryptionKey = "key123";

        bytes32 provenanceHash = keccak256(abi.encodePacked(originalURI, encryptionKey, block.chainid));
        bytes memory encryptedURI = _encryptDecrypt(bytes(originalURI), encryptionKey);
        bytes memory encryptedData = abi.encode(encryptedURI, provenanceHash);

        vm.prank(owner);
        DelayedRevealExt(address(core)).uploadMetadata(100, tempURI, encryptedData);

        // read state from core
        assertEq(core.tokenURI(1), "ipfs://temp/0");
        assertEq(core.tokenURI(99), "ipfs://temp/0");
    }

    function test_state_reveal() public {
        string memory originalURI = "ipfs://original/";
        string memory tempURI = "ipfs://temp/";
        bytes memory encryptionKey = "key123";

        bytes32 provenanceHash = keccak256(abi.encodePacked(originalURI, encryptionKey, block.chainid));
        bytes memory encryptedURI = _encryptDecrypt(bytes(originalURI), encryptionKey);
        bytes memory encryptedData = abi.encode(encryptedURI, provenanceHash);

        vm.prank(owner);
        DelayedRevealExt(address(core)).uploadMetadata(100, tempURI, encryptedData);

        // reveal
        vm.prank(owner);
        DelayedRevealExt(address(core)).reveal(0, encryptionKey);

        // read state from core
        assertEq(core.tokenURI(1), "ipfs://original/1");
        assertEq(core.tokenURI(99), "ipfs://original/99");
    }

    function test_getRevealURI() public {
        string memory originalURI = "ipfs://original/";
        string memory tempURI = "ipfs://temp/";
        bytes memory encryptionKey = "key123";

        bytes32 provenanceHash = keccak256(abi.encodePacked(originalURI, encryptionKey, block.chainid));
        bytes memory encryptedURI = _encryptDecrypt(bytes(originalURI), encryptionKey);
        bytes memory encryptedData = abi.encode(encryptedURI, provenanceHash);

        vm.prank(owner);
        DelayedRevealExt(address(core)).uploadMetadata(100, tempURI, encryptedData);

        // get reveal URI
        uint256 index = 0;

        DelayedRevealBatchMetadataERC721.DelayedRevealMetadataBatch[] memory batches =
            DelayedRevealExt(address(core)).getAllMetadataBatches();

        bytes memory encryptedDataStored = batches[index].encryptedData;
        (bytes memory encryptedURIStored,) = abi.decode(encryptedDataStored, (bytes, bytes32));

        string memory revealURI = string(_encryptDecrypt(encryptedURIStored, encryptionKey));

        assertEq(revealURI, originalURI);

        // state unchanged
        assertEq(core.tokenURI(1), "ipfs://temp/0");
        assertEq(core.tokenURI(99), "ipfs://temp/0");
    }

}

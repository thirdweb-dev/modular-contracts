// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

// Test util
import { ERC721BenchmarkBase } from "../ERC721BenchmarkBase.t.sol";
import { CloneFactory } from "src/CloneFactory.sol";

// Target test contracts
import { ERC721CreatorUpgradeable } from "./utils/ERC721CreatorUpgradeable.sol";
import { ERC721LazyMintWhitelist } from "./utils/ERC721LazyMintWhitelist.sol";

contract ManifoldERC721BenchmarkTest is ERC721BenchmarkBase {

    ERC721LazyMintWhitelist internal claimContract;

    function setUp() public override {
        super.setUp();
        
        vm.startPrank(admin);

        // Deploy infra/shared-state contracts pre-setup
        claimContract = new ERC721LazyMintWhitelist(erc721Contract, "test");
        
        // Set allowlist
        string[] memory inputs = new string[](2);
        inputs[0] = "node";
        inputs[1] = "test/scripts/generateRoot.ts";
        
        bytes memory result = vm.ffi(inputs);
        bytes32 root = abi.decode(result, (bytes32));
        
        claimContract.setAllowList(root);

        // Register extension
        ERC721CreatorUpgradeable(erc721Contract).registerExtension(address(claimContract), "extensionURI");

        vm.stopPrank();
    }

    function _deployERC721ContractImplementation() internal override returns (address) {
        return address(new ERC721CreatorUpgradeable());
    }

    /// @dev Creates an instance of the target erc721 contract to benchmark.
    function _createERC721Contract(address _implementation) internal override returns (address) {
        vm.roll(block.number + 100);

        vm.pauseGasMetering();

        CloneFactory factory = new CloneFactory();
        
        vm.resumeGasMetering();

        // NOTE: Below, we use the inline hex for `abi.encodeWithSelector(...)` for more accurate gas measurement -- this is because
        //       forge will account for the gas cost of all computation such as `abi.encodeWithSelector(...)`.
        //
        return 
                factory.deployProxyByImplementation(
                    _implementation, 
                    abi.encodeWithSelector(ERC721CreatorUpgradeable.initialize.selector, admin, "Test", "TST"),
                    bytes32(block.number)
                );
        
        // return factory.deployProxyByImplementation(
        //     _implementation, 
        //     hex"2016a0d20000000000000000000000000000000000000000000000000000000000000123000000000000000000000000f62849f9a0b5bf2913b396098f7c7019b51a820a000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000004546573740000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000035453540000000000000000000000000000000000000000000000000000000000", 
        //     bytes32(block.number)
        // );
    }

    /// @dev Setup token metadata
    function _setupTokenMetadata() internal override {

        vm.pauseGasMetering();
        ERC721LazyMintWhitelist claimC = claimContract;

        string[] memory inputs = new string[](2);
        inputs[0] = "node";
        inputs[1] = "test/scripts/getProof.ts";
        
        bytes memory result = vm.ffi(inputs);
        bytes32[] memory proofs = abi.decode(result, (bytes32[]));

        vm.prank(claimer);
        claimC.mint{value: pricePerToken}(proofs);

        vm.resumeGasMetering();

        vm.prank(admin);
        claimC.setTokenURIPrefix("https://example.com/");
    }

    /// @dev Claims a token from the target erc721 contract.
    function _claimOneToken(address _claimer, uint256 _price) internal override returns (uint256) {

        vm.pauseGasMetering();
        ERC721LazyMintWhitelist claimC = claimContract;

        string[] memory inputs = new string[](2);
        inputs[0] = "node";
        inputs[1] = "test/scripts/getProof.ts";
        
        bytes memory result = vm.ffi(inputs);
        bytes32[] memory proofs = abi.decode(result, (bytes32[]));

        vm.resumeGasMetering();

        vm.prank(_claimer);
        claimC.mint{value: _price}(proofs);

        return 1;
    }
}

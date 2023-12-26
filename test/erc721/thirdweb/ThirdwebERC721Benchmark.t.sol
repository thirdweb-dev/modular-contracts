// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

// Test util
import { ERC721BenchmarkBase } from "../ERC721BenchmarkBase.t.sol";
import { CloneFactory } from "src/infra/CloneFactory.sol";

// Target test contracts
import { ERC721Core } from "src/erc721/ERC721Core.sol";
import { ERC721SimpleClaim } from "src/erc721/ERC721SimpleClaim.sol";
import { ERC721MetadataSimple } from "src/erc721/ERC721MetadataSimple.sol";
import { Permissions } from "src/extension/Permissions.sol";

contract ThirdwebERC721BenchmarkTest is ERC721BenchmarkBase {

    ERC721MetadataSimple internal erc721MetadataSource;
    ERC721SimpleClaim public simpleClaim;

    function setUp() public override {
        
        // Deploy infra/shared-state contracts pre-setup
        simpleClaim = new ERC721SimpleClaim();
        erc721MetadataSource = new ERC721MetadataSimple();

        super.setUp();

        // Grant minter role to `ERC721SimpleClaim` contract.
        vm.prank(admin);
        Permissions(erc721Contract).grantRole(address(simpleClaim), 1);

        // Setup claim condition
        string[] memory inputs = new string[](2);
        inputs[0] = "node";
        inputs[1] = "test/scripts/generateRoot.ts";
        
        bytes memory result = vm.ffi(inputs);
        bytes32 root = abi.decode(result, (bytes32));

        ERC721SimpleClaim.ClaimCondition memory condition = ERC721SimpleClaim.ClaimCondition({
            price: pricePerToken,
            availableSupply: 5,
            allowlistMerkleRoot: root,
            saleRecipient: admin
        });
        
        vm.prank(admin);
        simpleClaim.setClaimCondition(erc721Contract, condition);
    }

    /// @dev Optional: deploy the target erc721 contract's implementation.
    function _deployERC721ContractImplementation() internal override returns (address) {
        return address(new ERC721Core());
    }

    /// @dev Creates an instance of the target erc721 contract to benchmark.
    function _createERC721Contract(address _implementation) internal override returns (address) {
        vm.roll(block.number + 100);

        vm.pauseGasMetering();

        CloneFactory factory = new CloneFactory();

        // NOTE: Below, we use the inline hex for `abi.encodeWithSelector(...)` for more accurate gas measurement -- this is because
        //       forge will account for the gas cost of all computation such as `abi.encodeWithSelector(...)`.
        //
        // return address(
        //     ERC721Core(
        //         cloneFactory.deployProxyByImplementation(
        //             _implementation, 
        //             abi.encodeWithSelector(ERC721Core.initialize.selector, admin, address(erc721MetadataSource), "Test", "TST"), 
        //             bytes32(block.number)
        //         )
        //     )
        // );
        
        vm.resumeGasMetering();
        
        return factory.deployProxyByImplementation(
            _implementation, 
            hex"2016a0d20000000000000000000000000000000000000000000000000000000000000123000000000000000000000000f62849f9a0b5bf2913b396098f7c7019b51a820a000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000004546573740000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000035453540000000000000000000000000000000000000000000000000000000000", 
            bytes32(block.number)
        );
    }

    /// @dev Setup token metadata
    function _setupTokenMetadata() internal override {

        vm.pauseGasMetering();
        ERC721MetadataSimple source = erc721MetadataSource;
        address erc721 = erc721Contract;
        vm.prank(address(0x123));
        vm.resumeGasMetering();
        
        source.setTokenURI(erc721, 0, "https://example.com/0.json");
    }

    /// @dev Claims a token from the target erc721 contract.
    function _claimOneToken(address _claimer, uint256 _price) internal override returns (uint256) {

        vm.pauseGasMetering();
        
        ERC721SimpleClaim claimContract = simpleClaim;
        address erc721 = erc721Contract;

        string[] memory inputs = new string[](2);
        inputs[0] = "node";
        inputs[1] = "test/scripts/getProof.ts";
        
        bytes memory result = vm.ffi(inputs);
        bytes32[] memory proofs = abi.decode(result, (bytes32[]));

        vm.resumeGasMetering();

        vm.prank(_claimer);
        claimContract.claim{value: _price}(erc721, proofs);
        
        return 0;
    }
}
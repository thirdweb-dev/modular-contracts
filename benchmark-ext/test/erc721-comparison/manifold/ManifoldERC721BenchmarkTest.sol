// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

// Test util
import { ERC721BenchmarkBase } from "../ERC721BenchmarkBase.t.sol";
import { Merkle } from "@murky/Merkle.sol";

// Target test contracts
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC721LazyMintWhitelist } from "@manifoldxyz/creator-core-extensions-solidity/lazywhitelist/contracts/ERC721LazyMintWhitelist.sol";
import { ERC721CreatorUpgradeable } from "@manifoldxyz/creator-core-solidity/contracts/ERC721CreatorUpgradeable.sol";

contract ManifoldERC721BenchmarkTest is ERC721BenchmarkBase {
    ERC721LazyMintWhitelist internal claimContract;

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);

        // Deploy infra/shared-state contracts pre-setup
        claimContract = new ERC721LazyMintWhitelist(erc721Contract, "test");

        // Set allowlist
        address[] memory addresses = new address[](3);
        addresses[0] = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;
        addresses[1] = 0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3;
        addresses[2] = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
        Merkle merkle = new Merkle();
        bytes32[] memory data = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            data[i] = bytes32(keccak256(abi.encodePacked(addresses[i])));
        }
        bytes32 root = merkle.getRoot(data);

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
        vm.prank(address(0x123)); // admin

        // NOTE: Below, we use the inline hex for `abi.encodeWithSelector(...)` for more accurate gas measurement -- this is because
        //       forge will account for the gas cost of all computation such as `abi.encodeWithSelector(...)`.
        //
        // return address(
        //     new ERC1967Proxy(
        //         _implementation,
        //         abi.encodeWithSelector(ERC721CreatorUpgradeable.initialize.selector, "Test", "TST")
        //     )
        // );

        return
            address(
                new ERC1967Proxy(
                    _implementation,
                    hex"4cd88b76000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000004546573740000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000035453540000000000000000000000000000000000000000000000000000000000"
                )
            );
    }

    /// @dev Setup token metadata
    function _setupTokenMetadata() internal override {
        vm.pauseGasMetering();
        ERC721LazyMintWhitelist claimC = claimContract;
        vm.prank(admin);
        vm.resumeGasMetering();

        claimC.setTokenURIPrefix("https://example.com/");
    }

    /// @dev Claims a token from the target erc721 contract.
    function _claimOneToken(address _claimer, uint256 _price) internal override returns (uint256) {
        vm.pauseGasMetering();
        ERC721LazyMintWhitelist claimC = claimContract;

        address[] memory addresses = new address[](3);
        addresses[0] = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;
        addresses[1] = 0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3;
        addresses[2] = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
        Merkle merkle = new Merkle();
        bytes32[] memory data = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            data[i] = bytes32(keccak256(abi.encodePacked(addresses[i])));
        }
        bytes32[] memory proofs = merkle.getProof(data, 0);

        vm.resumeGasMetering();

        vm.prank(_claimer);
        claimC.mint{ value: _price }(proofs);

        return 1;
    }

    /// @dev Claims a token from the target erc721 contract.
    function _claimOneTokenCopy(address _claimer, uint256 _price) internal override returns (uint256) {
        ERC721LazyMintWhitelist claimC = claimContract;

        address[] memory addresses = new address[](3);
        addresses[0] = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;
        addresses[1] = 0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3;
        addresses[2] = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
        Merkle merkle = new Merkle();
        bytes32[] memory data = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            data[i] = bytes32(keccak256(abi.encodePacked(addresses[i])));
        }
        bytes32[] memory proofs = merkle.getProof(data, 0);

        vm.prank(_claimer);
        claimC.mint{ value: _price }(proofs);

        return 1;
    }
}

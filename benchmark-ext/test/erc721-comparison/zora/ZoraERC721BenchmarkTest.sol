// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

// Test util
import { ERC721BenchmarkBase } from "../ERC721BenchmarkBase.t.sol";

// Target test contracts
import { ProtocolRewards } from "@zoralabs/protocol-rewards/src/ProtocolRewards.sol";
import { EditionMetadataRenderer } from "@zoralabs/zora-721-contracts/metadata/EditionMetadataRenderer.sol";
import { IMetadataRenderer, DropMetadataRenderer } from "@zoralabs/zora-721-contracts/metadata/DropMetadataRenderer.sol";
import { ERC721Drop } from "@zoralabs/zora-721-contracts/ERC721Drop.sol";
import { FactoryUpgradeGate, IFactoryUpgradeGate } from "@zoralabs/zora-721-contracts/FactoryUpgradeGate.sol";
import { ZoraNFTCreatorV1 } from "@zoralabs/zora-721-contracts/ZoraNFTCreatorV1.sol";
import { Merkle } from "@murky/Merkle.sol";

contract ZoraERC721BenchmarkTest is ERC721BenchmarkBase {
    function setUp() public override {
        super.setUp();

        // Generate allowlist
        address[] memory addresses = new address[](3);
        addresses[0] = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;
        addresses[1] = 0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3;
        addresses[2] = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
        Merkle merkle = new Merkle();
        bytes32[] memory data = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            data[i] = bytes32(keccak256(abi.encode(addresses[i], uint256(300), uint256(100000000000000000))));
        }
        bytes32 root = merkle.getRoot(data);

        // Set sale details
        vm.prank(admin);
        ERC721Drop(payable(erc721Contract)).setSaleConfiguration(
            uint104(pricePerToken),
            1,
            10_000,
            20_000,
            0,
            9999,
            root
        );
    }

    function _deployERC721ContractImplementation() internal override returns (address) {
        return
            address(
                new ERC721Drop(
                    address(0),
                    IFactoryUpgradeGate(address(new FactoryUpgradeGate(admin))),
                    0,
                    payable(admin),
                    address(new ProtocolRewards())
                )
            );
    }

    function _createERC721Contract(address _implementation) internal override returns (address) {
        vm.roll(block.number + 100);

        vm.pauseGasMetering();

        EditionMetadataRenderer edition = new EditionMetadataRenderer();
        DropMetadataRenderer drop = new DropMetadataRenderer();
        ZoraNFTCreatorV1 zora = new ZoraNFTCreatorV1(_implementation, edition, drop);

        IMetadataRenderer metadataRenderer = IMetadataRenderer(address(drop));
        bytes memory metadataInit = abi.encode("https://initialilMetadata/", "https://initialilURI/");

        vm.resumeGasMetering();

        return
            zora.createAndConfigureDrop(
                "Test",
                "TST",
                address(0x123),
                100,
                0,
                payable(address(0x123)),
                new bytes[](0),
                metadataRenderer,
                metadataInit,
                address(0)
            );
    }

    /// @dev Setup token metadata
    function _setupTokenMetadata() internal override {
        vm.pauseGasMetering();
        address erc721 = erc721Contract;
        (IMetadataRenderer metadata, , , ) = ERC721Drop(payable(erc721)).config();
        DropMetadataRenderer renderer = DropMetadataRenderer(address(metadata));

        vm.resumeGasMetering();
        vm.prank(address(0x123));
        renderer.updateMetadataBase(erc721, "https://example/", "https://example/");
    }

    /// @dev Claims a token from the target erc721 contract.
    function _claimOneToken(address _claimer, uint256 _price) internal override returns (uint256) {
        vm.pauseGasMetering();
        ERC721Drop claimC = ERC721Drop(payable(erc721Contract));

        address[] memory addresses = new address[](3);
        addresses[0] = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;
        addresses[1] = 0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3;
        addresses[2] = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
        Merkle merkle = new Merkle();
        bytes32[] memory data = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            data[i] = bytes32(keccak256(abi.encode(addresses[i], uint256(300), uint256(100000000000000000))));
        }
        bytes32[] memory proof = merkle.getProof(data, 0);

        uint256 price = _price;
        uint256 quantity = 1;
        uint256 maxQuantity = 300;
        uint256 fee = 0.000777 ether;

        vm.resumeGasMetering();

        vm.prank(_claimer);
        claimC.purchasePresale{ value: price + fee }(quantity, maxQuantity, price, proof);

        return 1;
    }

    /// @dev Claims a token from the target erc721 contract.
    function _claimOneTokenCopy(address _claimer, uint256 _price) internal override returns (uint256) {
        ERC721Drop claimC = ERC721Drop(payable(erc721Contract));

        address[] memory addresses = new address[](3);
        addresses[0] = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;
        addresses[1] = 0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3;
        addresses[2] = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
        Merkle merkle = new Merkle();
        bytes32[] memory data = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            data[i] = bytes32(keccak256(abi.encode(addresses[i], uint256(300), uint256(100000000000000000))));
        }
        bytes32[] memory proof = merkle.getProof(data, 0);

        uint256 price = _price;
        uint256 quantity = 1;
        uint256 maxQuantity = 300;
        uint256 fee = 0.000777 ether;

        vm.prank(_claimer);
        claimC.purchasePresale{ value: price + fee }(quantity, maxQuantity, price, proof);

        return 1;
    }
}

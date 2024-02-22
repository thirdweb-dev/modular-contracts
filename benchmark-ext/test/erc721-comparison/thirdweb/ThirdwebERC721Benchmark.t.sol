// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

// Test util
import { ERC721BenchmarkBase } from "../ERC721BenchmarkBase.t.sol";
import { CloneFactory } from "@contracts-next/infra/CloneFactory.sol";
import { EIP1967Proxy } from "@contracts-next/infra/EIP1967Proxy.sol";
import { MinimalUpgradeableRouter } from "@contracts-next/infra/MinimalUpgradeableRouter.sol";
import { IHook } from "@contracts-next/interface/hook/IHook.sol";
import { IInitCall } from "@contracts-next/interface/common/IInitCall.sol";
import { Merkle } from "@murky/Merkle.sol";

// Target test contracts
import { ERC721Core } from "@contracts-next/core/token/ERC721Core.sol";
import { AllowlistMintHookERC721 } from "@contracts-next/hook/mint/AllowlistMintHookERC721.sol";
import { SimpleMetadataHook } from "@contracts-next/hook/metadata/SimpleMetadataHook.sol";
import { Permission } from "@contracts-next/common/Permission.sol";

contract ThirdwebERC721BenchmarkTest is ERC721BenchmarkBase {
    AllowlistMintHookERC721 public simpleClaim;
    SimpleMetadataHook public simpleMetadataHook;

    function setUp() public override {
        // Deploy infra/shared-state contracts pre-setup
        address hookProxyAddress = address(
            new EIP1967Proxy(
                address(new AllowlistMintHookERC721()),
                abi.encodeWithSelector(AllowlistMintHookERC721.initialize.selector, admin)
            )
        );
        simpleClaim = AllowlistMintHookERC721(hookProxyAddress);

        address simpleMetadataHookProxyAddress = address(
            new MinimalUpgradeableRouter(admin, address(new SimpleMetadataHook()))
        );
        simpleMetadataHook = SimpleMetadataHook(simpleMetadataHookProxyAddress);

        super.setUp();

        // Set `AllowlistMintHookERC721` contract as minter
        vm.startPrank(admin);
        ERC721Core(erc721Contract).installHook(IHook(address(simpleClaim)));
        ERC721Core(erc721Contract).installHook(IHook(address(simpleMetadataHook)));
        vm.stopPrank();

        // Setup claim condition
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

        AllowlistMintHookERC721.ClaimCondition memory condition = AllowlistMintHookERC721.ClaimCondition({
            price: pricePerToken,
            availableSupply: 5,
            allowlistMerkleRoot: root
        });

        vm.prank(admin);
        ERC721Core(erc721Contract).hookFunctionWrite(
            2,
            0,
            abi.encodeWithSelector(AllowlistMintHookERC721.setClaimCondition.selector, condition)
        );

        AllowlistMintHookERC721.FeeConfig memory feeConfig;
        feeConfig.primarySaleRecipient = admin;
        feeConfig.platformFeeRecipient = address(0x789);
        feeConfig.platformFeeBps = 100; // 1%

        vm.prank(admin);
        ERC721Core(erc721Contract).hookFunctionWrite(
            2,
            0,
            abi.encodeWithSelector(AllowlistMintHookERC721.setDefaultFeeConfig.selector, feeConfig)
        );
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
        IInitCall.InitCall memory initCall;

        vm.resumeGasMetering();

        // NOTE: Below, we use the inline hex for `abi.encodeWithSelector(...)` for more accurate gas measurement -- this is because
        //       forge will account for the gas cost of all computation such as `abi.encodeWithSelector(...)`.
        //
        return
            address(
                ERC721Core(
                    factory.deployProxyByImplementation(
                        _implementation,
                        abi.encodeWithSelector(
                            ERC721Core.initialize.selector,
                            initCall,
                            new address[](0),
                            admin,
                            "Test",
                            "TST",
                            "contractURI://"
                        ),
                        bytes32(block.number)
                    )
                )
            );

        // vm.resumeGasMetering();

        // return factory.deployProxyByImplementation(
        //     _implementation,
        //     hex"61edddb500000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000012300000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004546573740000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000035453540000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e636f6e74726163745552493a2f2f000000000000000000000000000000000000",
        //     bytes32(block.number)
        // );
    }

    /// @dev Setup token metadata
    function _setupTokenMetadata() internal override {
        vm.pauseGasMetering();
        SimpleMetadataHook hook = simpleMetadataHook;
        address erc721 = erc721Contract;
        vm.prank(address(0x123));
        vm.resumeGasMetering();

        ERC721Core(erc721Contract).hookFunctionWrite(
            2 ** 5,
            0,
            abi.encodeWithSelector(SimpleMetadataHook.setTokenURI.selector, 0, "https://example.com/")
        );
    }

    /// @dev Claims a token from the target erc721 contract.
    function _claimOneToken(address _claimer, uint256 _price) internal override returns (uint256) {
        vm.pauseGasMetering();

        ERC721Core claimContract = ERC721Core(erc721Contract);

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

        bytes memory encodedArgs = abi.encode(proofs);

        vm.resumeGasMetering();

        vm.prank(_claimer);
        claimContract.mint{ value: _price }(_claimer, 1, encodedArgs);
    }

    /// @dev Claims a token from the target erc721 contract.
    function _claimOneTokenCopy(address _claimer, uint256 _price) internal override returns (uint256) {
        ERC721Core claimContract = ERC721Core(erc721Contract);

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

        bytes memory encodedArgs = abi.encode(proofs);

        vm.prank(_claimer);
        claimContract.mint{ value: _price }(claimer, 1, encodedArgs);

        return 0;
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { IERC721 } from "./interface/IERC721.sol";

abstract contract ERC721BenchmarkBase is Test {
    address internal admin;
    address internal claimer;
    address internal transferRecipient;

    uint256 internal pricePerToken = 0.1 ether;

    address internal erc721ContractImplementation;
    address internal erc721Contract;

    function setUp() public virtual {
        admin = address(0x123);
        claimer = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;
        transferRecipient = address(0x789);

        vm.deal(claimer, 1 ether);

        vm.label(admin, "Admin");
        vm.label(claimer, "Claimer");
        vm.label(transferRecipient, "TransferRecipient");

        erc721ContractImplementation = _deployERC721ContractImplementation();
        erc721Contract = _createERC721Contract(erc721ContractImplementation);
    }

    /// @dev Optional: deploy the target erc721 contract's implementation.
    function _deployERC721ContractImplementation() internal virtual returns (address);

    /// @dev Creates an instance of the target erc721 contract to benchmark.
    function _createERC721Contract(address _implementation) internal virtual returns (address);

    /// @dev Setup token metadata
    function _setupTokenMetadata() internal virtual;

    /// @dev Claims a token from the target erc721 contract.
    function _claimOneToken(address _claimer, uint256 _price) internal virtual returns (uint256 tokenId);

    /// @dev NOTE: This is a copy of `_claimOneToken` for benchmarking purposes. SHOULD NOT contain any vm.pause/resumeGasMetering calls.
    function _claimOneTokenCopy(address _claimer, uint256 _price) internal virtual returns (uint256 tokenId);

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function testBenchmarkDeployContract() public {
        vm.pauseGasMetering();
        address implementation = erc721ContractImplementation;
        vm.resumeGasMetering();

        _createERC721Contract(implementation);
    }

    function testBenchmarkClaimToken() public {
        vm.pauseGasMetering();
        address claimerAddr = claimer;
        uint256 price = pricePerToken;
        vm.resumeGasMetering();
        _claimOneToken(claimerAddr, price);
    }

    function testBenchmarkTransferToken() public {
        vm.pauseGasMetering();

        IERC721 erc721 = IERC721(erc721Contract);

        uint256 tokenId = _claimOneTokenCopy(claimer, pricePerToken);
        address claimerAddr = claimer;
        address recipient = transferRecipient;

        vm.startPrank(claimerAddr);

        vm.resumeGasMetering();
        erc721.transferFrom(claimerAddr, recipient, tokenId);

        vm.stopPrank();
    }

    function testBenchmarkSetupTokenMetadata() public {
        _setupTokenMetadata();
    }
}

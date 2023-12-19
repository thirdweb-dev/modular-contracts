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
    
    function setUp() public {

        admin = address(0x123);
        claimer = address(0x456);
        transferRecipient = address(0x789);

        vm.label(admin, "Admin");
        vm.label(claimer, "Claimer");
        vm.label(transferRecipient, "TransferRecipient");

        erc721ContractImplementation = _deployERC721ContractImplementation();
        _createERC721Contract(erc721ContractImplementation);
    }

    /// @dev Optional: deploy the target erc721 contract's implementation.
    function _deployERC721ContractImplementation() internal virtual returns (address);

    /// @dev Creates an instance of the target erc721 contract to benchmark.
    function _createERC721Contract(address _implementation) internal virtual returns (address);

    /// @dev Setup token metadata
    function _setupTokenMetadata() internal virtual;

    /// @dev Claims a token from the target erc721 contract.
    function _claimToken(address _claimer, uint256 _price, uint256 _quantity) internal virtual;

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function testBenchmarkDeployContract() public {
        _createERC721Contract(erc721ContractImplementation);
    }

    function testBenchmarkClaimToken() public {
        _claimToken(claimer, pricePerToken, 1);
    }

    function testBenchmarkTransferToken() public {

        vm.pauseGasMetering();

        _claimToken(claimer, pricePerToken, 1);

        vm.startPrank(claimer);

        vm.resumeGasMetering(); 
        IERC721(claimer).transferFrom(claimer, transferRecipient, 0);
        vm.pauseGasMetering();

        vm.stopPrank();
    }

    function testBenchmarkSetupTokenMetadata() public {
        _setupTokenMetadata();
    }
}
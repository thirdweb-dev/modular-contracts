// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "./BenchmarkERC721Base.sol";

interface IBenchmarkERC721 {
    function deployProxyByImplementation(
        address _implementation,
        bytes calldata _data,
        bytes32 _salt
    ) external returns (address deployedProxy);

    function initialize(
        address _defaultAdmin,
        string memory _name,
        string memory _symbol,
        string memory _contractURI,
        address[] memory _trustedForwarders,
        address _saleRecipient,
        address _royaltyRecipient,
        uint128 _royaltyBps,
        uint128 _platformFeeBps,
        address _platformFeeRecipient
    ) external;
}

contract BenchmarkERC721ThirdwebLegacy is BenchmarkERC721Base {
    function _deployContract(
        address deployerAddress,
        string memory name,
        string memory symbol,
        string memory contractURI
    ) internal override returns (address contractAddress) {
        bytes memory encodedInitializer = abi.encodeCall(
            IBenchmarkERC721.initialize,
            (
                deployerAddress,
                name,
                symbol,
                contractURI,
                new address[](0),
                deployerAddress,
                deployerAddress,
                0,
                0,
                deployerAddress
            )
        );

        contractAddress = IBenchmarkERC721(
            0x76F948E5F13B9A84A81E5681df8682BBf524805E
        ).deployProxyByImplementation(
                0x6F6010fB5da6f757D5b1822Aadf1D3B806D6546d,
                encodedInitializer,
                bytes32(
                    0x3531393037313300000000000000000000000000000000000000000000000000
                )
            );
    }

    function _setupToken() internal override {}

    function _mintToken() internal override {}

    function _mintBatchHundredTokens() internal override {}

    function _transferToken() internal override {}
}

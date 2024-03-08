// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "./BenchmarkERC721Base.sol";

interface IBenchmarkERC721 {
    function deployProxyByImplementation(address _implementation, bytes calldata _data, bytes32 _salt)
        external
        returns (address deployedProxy);

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

interface IThirdwebNFT {
    function mintTo(address _to, string calldata _uri) external returns (uint256);
}

contract BenchmarkERC721ThirdwebLegacy is BenchmarkERC721Base {
    function deployContract(
        address deployerAddress,
        string memory name,
        string memory symbol,
        string memory contractURI
    ) external override returns (address contractAddress) {
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

        contractAddress = IBenchmarkERC721(0x76F948E5F13B9A84A81E5681df8682BBf524805E).deployProxyByImplementation(
            0xd534AC695ab818863FdE799afb2335F989C935e0,
            encodedInitializer,
            bytes32(0x3534313939303300000000000000000000000000000000000000000000000000)
        );
    }

    function setupToken(address contractAddress) external override {}

    function mintToken(address contractAddress) external override {
        IThirdwebNFT(contractAddress).mintTo(tx.origin, "ipfs://QmVKEzCzn2wnakB33f2Zqhdnk5LrQiAKbuTA95bFcmKuUR/0");
    }

    function mintBatchTokens(address contractAddress) external override {}

    function transferTokenFrom(address contractAddress) external override {
        IERC721(contractAddress).transferFrom(tx.origin, address(0xdead), 0);
    }
}

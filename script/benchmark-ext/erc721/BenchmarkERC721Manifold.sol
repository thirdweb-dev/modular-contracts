// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "./BenchmarkERC721Base.sol";

library StorageSlot {
    struct AddressSlot {
        address value;
    }

    function getAddressSlot(bytes32 slot)
        internal
        pure
        returns (AddressSlot storage r)
    {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }
}

abstract contract Proxy {
    function _delegate(address implementation) internal virtual {
        assembly {
            calldatacopy(0, 0, calldatasize())

            let result := delegatecall(
                gas(),
                implementation,
                0,
                calldatasize(),
                0,
                0
            )

            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    function _implementation() internal view virtual returns (address);

    function _fallback() internal virtual {
        _delegate(_implementation());
    }

    fallback() external payable virtual {
        _fallback();
    }
}

contract ERC721Creator is Proxy {
    constructor(string memory name, string memory symbol) {
        assert(
            _IMPLEMENTATION_SLOT ==
                bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );
        StorageSlot
            .getAddressSlot(_IMPLEMENTATION_SLOT)
            .value = 0x07aee92b7C5977F5EC15d20BaC713A21f72F287B;
        (bool success, ) = 0x07aee92b7C5977F5EC15d20BaC713A21f72F287B
            .delegatecall(
                abi.encodeWithSignature(
                    "initialize(string,string)",
                    name,
                    symbol
                )
            );
        require(success, "Initialization failed");
    }

    bytes32 internal constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function implementation() public view returns (address) {
        return _implementation();
    }

    function _implementation() internal view override returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }
}

contract BenchmarkERC721Manifold is BenchmarkERC721Base {
    function _deployContract(
        address deployerAddress,
        string memory name,
        string memory symbol,
        string memory contractURI
    ) internal override returns (address contractAddress) {
        //Reference:
        // https://sepolia.etherscan.io/address/0xfc958641e52563f071534495886a8ac590dcbfa2#code
        // https://sepolia.etherscan.io/tx/0xbc029723fbfd3cfef3c47c523bc9a4e7f073d6f0e89de3f5761701adbd4118a8
        contractAddress = address(new ERC721Creator(name, symbol));
    }

    function _setupToken() internal override {}

    function _mintToken() internal override {
        // ERC721 Mint token
        // https://sepolia.etherscan.io/tx/0x05e54d052b160cf46e8133c2cb4fb5ecfec754e791ae8dd7197a02d332531899
        // https://sepolia.etherscan.io/tx/0x6815e65fc7376ba80daa8cbe0bd1bd63476bf78639a554702f981b5545ba0732
    }

    function _mintBatchHundredTokens() internal override {}

    function _transferToken() internal override {}
}

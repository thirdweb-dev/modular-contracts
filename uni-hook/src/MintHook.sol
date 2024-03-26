// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

// permissioned mint, mint with signature, claim

import {BeforeMintHookERC20} from "@core-contracts/hook/BeforeMintHookERC20.sol";
import {BeforeMintHookERC721} from "@core-contracts/hook/BeforeMintHookERC721.sol";
import {BeforeMintHookERC1155} from "@core-contracts/hook/BeforeMintHookERC1155.sol";

import {Multicallable} from "@solady/utils/Multicallable.sol";

contract MintHook is BeforeMintHookERC20, BeforeMintHookERC721, BeforeMintHookERC1155, Multicallable {
    /*//////////////////////////////////////////////////////////////
                            STRUCTS & ENUMS
    //////////////////////////////////////////////////////////////*/

    enum MintMethod {
        SIGNATURE_MINT,
        ALLOWLIST_MINT
    }

    struct AllowlistClaimPhaseERC20 {
        uint256 availableSupply;
        bytes32 allowlistMerkleRoot;
        uint256 pricePerUnit;
        address currency;
        uint48 startTimestamp;
        uint48 endTimestamp;
    }

    struct AllowlistClaimParamsERC20 {
        uint256 quantity;
        bytes32[] allowlistProof;
        uint256 pricePerUnit;
        address currency;
    }

    struct AllowlistClaimPhaseERC721 {
        uint256 availableSupply;
        bytes32 allowlistMerkleRoot;
        uint256 pricePerUnit;
        address currency;
        uint48 startTimestamp;
        uint48 endTimestamp;
    }

    struct AllowlistClaimParamsERC721 {
        uint256 quantity;
        bytes32[] allowlistProof;
        uint256 pricePerUnit;
        address currency;
    }

    struct AllowlistClaimPhaseERC1155 {
        uint256 tokenId;
        uint256 availableSupply;
        bytes32 allowlistMerkleRoot;
        uint256 pricePerUnit;
        address currency;
        uint48 startTimestamp;
        uint48 endTimestamp;
    }

    struct AllowlistClaimParamsERC1155 {
        uint256 quantity;
        bytes32[] allowlistProof;
        uint256 pricePerUnit;
        address currency;
    }

    struct SignatureMintRequestERC20 {
        address token;
        uint48 startTimestamp;
        uint48 endTimestamp;
        address recipient;
        uint256 quantity;
        bytes32 uid;
    }

    struct SignatureMintRequestERC721 {
        address token;
        uint48 startTimestamp;
        uint48 endTimestamp;
        address recipient;
        uint256 quantity;
        bytes32 uid;
    }

    struct SignatureMintRequestERC1155 {
        uint256 tokenId;
        address token;
        uint48 startTimestamp;
        uint48 endTimestamp;
        address recipient;
        uint256 quantity;
        bytes32 uid;
    }

    struct SignatureMintParamsERC20 {
        SignatureMintRequestERC20 request;
        bytes signature;
    }

    struct SignatureMintParamsERC721 {
        SignatureMintRequestERC721 request;
        bytes signature;
    }

    struct SignatureMintParamsERC1155 {
        SignatureMintRequestERC1155 request;
        bytes signature;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 private constant TYPEHASH_SIGNATURE_MINT_ERC20 = keccak256(
        "SignatureMintRequestERC20(address token,uint48 startTimestamp,uint48 endTimestamp,address recipient,uint256 quantity,bytes32 uid)"
    );

    bytes32 private constant TYPEHASH_SIGNATURE_MINT_ERC721 = keccak256(
        "SignatureMintRequestERC721(address token,uint48 startTimestamp,uint48 endTimestamp,address recipient,uint256 quantity,bytes32 uid)"
    );

    bytes32 private constant TYPEHASH_SIGNATURE_MINT_ERC1155 = keccak256(
        "SignatureMintRequestERC1155(uint256 tokenId,address token,uint48 startTimestamp,uint48 endTimestamp,address recipient,uint256 quantity,bytes32 uid)"
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error MintHookInvalidMintMethod();

    /*//////////////////////////////////////////////////////////////
                            HOOK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function beforeMintERC20(address _to, uint256 _amount, bytes memory _data)
        external
        payable
        virtual
        override
        returns (bytes memory)
    {
        // Get minting method.
        MintMethod method = abi.decode(_data, (MintMethod));

        // Mint tokens based on the method.
        if (method == MintMethod.SIGNATURE_MINT) {
            (, SignatureMintParamsERC20 memory params) = abi.decode(_data, (MintMethod, SignatureMintParamsERC20));
            _mintWithSignatureERC20(params.request, params.signature);
        } else if (method == MintMethod.ALLOWLIST_MINT) {
            (, AllowlistClaimParamsERC20 memory params) = abi.decode(_data, (MintMethod, AllowlistClaimParamsERC20));
            _allowlistedMintERC20(params);
        } else {
            revert MintHookInvalidMintMethod();
        }
    }

    function beforeMintERC721(address _to, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        override
        returns (bytes memory)
    {
        // Get minting method.
        MintMethod method = abi.decode(_data, (MintMethod));

        // Mint tokens based on the method.
        if (method == MintMethod.SIGNATURE_MINT) {
            (, SignatureMintParamsERC721 memory params) = abi.decode(_data, (MintMethod, SignatureMintParamsERC721));
            _mintWithSignatureERC721(params.request, params.signature);
        } else if (method == MintMethod.ALLOWLIST_MINT) {
            (, AllowlistClaimParamsERC721 memory params) = abi.decode(_data, (MintMethod, AllowlistClaimParamsERC721));
            _allowlistedMintERC721(params);
        } else {
            revert MintHookInvalidMintMethod();
        }
    }

    function beforeMintERC1155(address _to, uint256 _id, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        override
        returns (bytes memory)
    {
        // Get minting method.
        MintMethod method = abi.decode(_data, (MintMethod));

        // Mint tokens based on the method.
        if (method == MintMethod.SIGNATURE_MINT) {
            (, SignatureMintParamsERC1155 memory params) = abi.decode(_data, (MintMethod, SignatureMintParamsERC1155));
            _mintWithSignatureERC1155(params.request, params.signature);
        } else if (method == MintMethod.ALLOWLIST_MINT) {
            (, AllowlistClaimParamsERC1155 memory params) = abi.decode(_data, (MintMethod, AllowlistClaimParamsERC1155));
            _allowlistedMintERC1155(params);
        } else {
            revert MintHookInvalidMintMethod();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _mintWithSignatureERC20(SignatureMintRequestERC20 memory _request, bytes memory _signature) internal {}

    function _mintWithSignatureERC721(SignatureMintRequestERC721 memory _request, bytes memory _signature) internal {}

    function _mintWithSignatureERC1155(SignatureMintRequestERC1155 memory _request, bytes memory _signature) internal {}

    function _allowlistedMintERC20(AllowlistClaimParamsERC20 memory _params) internal {}

    function _allowlistedMintERC721(AllowlistClaimParamsERC721 memory _params) internal {}

    function _allowlistedMintERC1155(AllowlistClaimParamsERC1155 memory _params) internal {}
}

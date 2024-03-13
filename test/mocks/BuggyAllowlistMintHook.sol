// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {MerkleProofLib} from "@solady/utils/MerkleProofLib.sol";

import {AllowlistMintHookERC20, AllowlistMintHookERC20Storage} from "src/hook/mint/AllowlistMintHookERC20.sol";
import {AllowlistMintHookERC721, AllowlistMintHookERC721Storage} from "src/hook/mint/AllowlistMintHookERC721.sol";
import {AllowlistMintHookERC1155, AllowlistMintHookERC1155Storage} from "src/hook/mint/AllowlistMintHookERC1155.sol";

contract BuggyAllowlistMintHookERC20 is AllowlistMintHookERC20 {
    /**
     *  @notice The beforeMint hook that is called by a core token before minting a token.
     *  @param _mintRequest The token mint request details.
     *  @return quantityToMint The quantity of tokens to mint.
     */
    function beforeMint(MintRequest calldata _mintRequest)
        external
        payable
        virtual
        override
        returns (uint256 quantityToMint)
    {
        address token = msg.sender;
        if (_mintRequest.token != msg.sender) {
            revert AllowlistMintHookNotToken();
        }

        AllowlistMintHookERC20Storage.Data storage data = AllowlistMintHookERC20Storage.data();

        ClaimCondition memory condition = data.claimCondition[token];

        if (_mintRequest.quantity == 0 || _mintRequest.quantity > condition.availableSupply) {
            revert AllowlistMintHookInvalidQuantity();
        }

        if (condition.allowlistMerkleRoot != bytes32(0)) {
            bytes32[] memory allowlistProof = _mintRequest.allowlistProof;

            bool isAllowlisted = MerkleProofLib.verify(
                allowlistProof, condition.allowlistMerkleRoot, keccak256(abi.encodePacked(_mintRequest.minter))
            );
            if (!isAllowlisted) {
                revert AllowlistMintHookNotInAllowlist(token, _mintRequest.minter);
            }
        }

        quantityToMint = uint96(_mintRequest.quantity);
        // `price` is interpreted as price per 1 ether unit of the ERC20 tokens.
        uint256 totalPrice = (_mintRequest.quantity * condition.price) / 1 ether;

        data.claimCondition[token].availableSupply -= _mintRequest.quantity;

        // BUG: FORGOT TO COLLECT PRICE!
        // _collectPrice(totalPrice);
    }
}

contract BuggyAllowlistMintHookERC721 is AllowlistMintHookERC721 {
    /**
     *  @notice The beforeMint hook that is called by a core token before minting a token.
     *  @param _mintRequest The request to mint tokens.
     *  @return tokenIdToMint The start tokenId to mint.
     *  @return quantityToMint The quantity of tokens to mint.
     */
    function beforeMint(MintRequest calldata _mintRequest)
        external
        payable
        virtual
        override
        returns (uint256 tokenIdToMint, uint256 quantityToMint)
    {
        address token = msg.sender;
        if (_mintRequest.token != msg.sender) {
            revert AllowlistMintHookNotToken();
        }

        AllowlistMintHookERC721Storage.Data storage data = AllowlistMintHookERC721Storage.data();

        ClaimCondition memory condition = data.claimCondition[token];

        if (_mintRequest.quantity == 0 || _mintRequest.quantity > condition.availableSupply) {
            revert AllowlistMintHookInvalidQuantity();
        }

        if (condition.allowlistMerkleRoot != bytes32(0)) {
            bytes32[] memory allowlistProof = _mintRequest.allowlistProof;

            bool isAllowlisted = MerkleProofLib.verify(
                allowlistProof, condition.allowlistMerkleRoot, keccak256(abi.encodePacked(_mintRequest.minter))
            );
            if (!isAllowlisted) {
                revert AllowlistMintHookNotInAllowlist(token, _mintRequest.minter);
            }
        }

        tokenIdToMint = data.nextTokenIdToMint[token];
        data.nextTokenIdToMint[token] += _mintRequest.quantity;

        quantityToMint = _mintRequest.quantity;

        data.claimCondition[token].availableSupply -= _mintRequest.quantity;

        // BUG: FORGOT TO COLLECT PRICE!
        // _collectPrice(condition.price * _mintRequest.quantity, tokenIdToMint);
    }
}

contract BuggyAllowlistMintHookERC1155 is AllowlistMintHookERC1155 {
    /**
     *  @notice The beforeMint hook that is called by a core token before minting a token.
     *  @param _mintRequest The token mint request details.
     *  @return tokenIdToMint The tokenId to mint.
     *  @return quantityToMint The quantity of tokens to mint.
     */
    function beforeMint(MintRequest calldata _mintRequest)
        external
        payable
        virtual
        override
        returns (uint256 tokenIdToMint, uint256 quantityToMint)
    {
        address token = msg.sender;
        if (_mintRequest.token != msg.sender) {
            revert AllowlistMintHookNotToken();
        }

        AllowlistMintHookERC1155Storage.Data storage data = AllowlistMintHookERC1155Storage.data();

        ClaimCondition memory condition = data.claimCondition[token][_mintRequest.tokenId];

        if (_mintRequest.quantity == 0 || _mintRequest.quantity > condition.availableSupply) {
            revert AllowlistMintHookInvalidQuantity();
        }

        if (condition.allowlistMerkleRoot != bytes32(0)) {
            bytes32[] memory allowlistProof = _mintRequest.allowlistProof;

            bool isAllowlisted = MerkleProofLib.verify(
                allowlistProof, condition.allowlistMerkleRoot, keccak256(abi.encodePacked(_mintRequest.minter))
            );
            if (!isAllowlisted) {
                revert AllowlistMintHookNotInAllowlist(token, _mintRequest.minter);
            }
        }

        tokenIdToMint = _mintRequest.tokenId;
        quantityToMint = _mintRequest.quantity;

        data.claimCondition[token][_mintRequest.tokenId].availableSupply -= _mintRequest.quantity;

        // BUG: FORGOT TO COLLECT PRICE!
        // _collectPrice(condition.price * _mintRequest.quantity, _mintRequest.tokenId);
    }
}

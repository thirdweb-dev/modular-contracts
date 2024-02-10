// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {MerkleProofLib} from "src/lib/MerkleProofLib.sol";

import {AllowlistMintExtensionERC20, AllowlistMintExtensionERC20Storage} from "src/extension/mint/AllowlistMintExtensionERC20.sol";
import {AllowlistMintExtensionERC721, AllowlistMintExtensionERC721Storage} from "src/extension/mint/AllowlistMintExtensionERC721.sol";
import {AllowlistMintExtensionERC1155, AllowlistMintExtensionERC1155Storage} from "src/extension/mint/AllowlistMintExtensionERC1155.sol";

contract BuggyAllowlistMintExtensionERC20 is AllowlistMintExtensionERC20 {
    function beforeMint(address _claimer, uint256 _quantity, bytes memory _encodedArgs)
        external
        payable
        virtual
        override
        returns (uint256 quantityToMint)
    {
        address token = msg.sender;
        AllowlistMintExtensionERC20Storage.Data storage data = AllowlistMintExtensionERC20Storage.data();

        ClaimCondition memory condition = data.claimCondition[token];

        if (_quantity == 0 || _quantity > condition.availableSupply) {
            revert AllowlistMintExtensionInvalidQuantity();
        }

        if (condition.allowlistMerkleRoot != bytes32(0)) {
            bytes32[] memory allowlistProof = abi.decode(_encodedArgs, (bytes32[]));

            bool isAllowlisted = MerkleProofLib.verify(
                allowlistProof, condition.allowlistMerkleRoot, keccak256(abi.encodePacked(_claimer))
            );
            if (!isAllowlisted) {
                revert AllowlistMintExtensionNotInAllowlist(token, _claimer);
            }
        }

        quantityToMint = uint96(_quantity);
        // `price` is interpreted as price per 1 ether unit of the ERC20 tokens.
        uint256 totalPrice = (_quantity * condition.price) / 1 ether;

        data.claimCondition[token].availableSupply -= _quantity;

        // BUG: FORGOT TO COLLECT PRICE!
        // _collectPrice(totalPrice);
    }
}

contract BuggyAllowlistMintExtensionERC721 is AllowlistMintExtensionERC721 {
    function beforeMint(address _claimer, uint256 _quantity, bytes memory _encodedArgs)
        external
        payable
        virtual
        override
        returns (uint256 tokenIdToMint, uint256 quantityToMint)
    {
        address token = msg.sender;
        AllowlistMintExtensionERC721Storage.Data storage data = AllowlistMintExtensionERC721Storage.data();

        ClaimCondition memory condition = data.claimCondition[token];

        if (_quantity == 0 || _quantity > condition.availableSupply) {
            revert AllowlistMintExtensionInvalidQuantity();
        }

        if (condition.allowlistMerkleRoot != bytes32(0)) {
            bytes32[] memory allowlistProof = abi.decode(_encodedArgs, (bytes32[]));

            bool isAllowlisted = MerkleProofLib.verify(
                allowlistProof, condition.allowlistMerkleRoot, keccak256(abi.encodePacked(_claimer))
            );
            if (!isAllowlisted) {
                revert AllowlistMintExtensionNotInAllowlist(token, _claimer);
            }
        }

        tokenIdToMint = data.nextTokenIdToMint[token]++;
        quantityToMint = _quantity;

        data.claimCondition[token].availableSupply -= _quantity;

        // BUG: FORGOT TO COLLECT PRICE!
        // _collectPrice(condition.price * _quantity);
    }
}

contract BuggyAllowlistMintExtensionERC1155 is AllowlistMintExtensionERC1155 {
    function beforeMint(address _claimer, uint256 _id, uint256 _value, bytes memory _encodedArgs)
        external
        payable
        virtual
        override
        returns (uint256 tokenIdToMint, uint256 quantityToMint)
    {
        address token = msg.sender;
        AllowlistMintExtensionERC1155Storage.Data storage data = AllowlistMintExtensionERC1155Storage.data();

        ClaimCondition memory condition = data.claimCondition[token][_id];

        if (_value == 0 || _value > condition.availableSupply) {
            revert AllowlistMintExtensionInvalidQuantity();
        }

        if (condition.allowlistMerkleRoot != bytes32(0)) {
            bytes32[] memory allowlistProof = abi.decode(_encodedArgs, (bytes32[]));

            bool isAllowlisted = MerkleProofLib.verify(
                allowlistProof, condition.allowlistMerkleRoot, keccak256(abi.encodePacked(_claimer))
            );
            if (!isAllowlisted) {
                revert AllowlistMintExtensionNotInAllowlist(token, _claimer);
            }
        }

        tokenIdToMint = _id;
        quantityToMint = _value;

        data.claimCondition[token][_id].availableSupply -= _value;

        // BUG: FORGOT TO COLLECT PRICE!
        // _collectPrice(condition.price * _value, _id);
    }
}

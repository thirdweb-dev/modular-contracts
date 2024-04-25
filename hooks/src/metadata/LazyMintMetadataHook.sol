// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IHook} from "@core-contracts/interface/IHook.sol";

import {HookFlagsDirectory} from "@core-contracts/callback/HookFlagsDirectory.sol";
import {OnTokenURICallback} from "@core-contracts/callback/OnTokenURICallback.sol";

import {LibString} from "@solady/utils/LibString.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";

library LazyMintStorage {
    /// @custom:storage-location erc7201:lazymint.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("lazymint.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant LAZY_MINT_STORAGE_POSITION =
        0x8911971c3aad928c9cac140eac0269f3210708ac8d69db5b5f5c70209d935800;

    struct Data {
        /// @notice Mapping from token => batch IDs
        mapping(address => uint256[]) batchIds;
        /// @notice Mapping from token => the next token ID to lazy mint.
        mapping(address => uint256) nextTokenIdToLazyMint;
        /// @notice Mapping from token => batchId => baseURI
        mapping(address => mapping(uint256 => string)) baseURI;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = LAZY_MINT_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract LazyMintMetadataHook is IHook, HookFlagsDirectory, OnTokenURICallback, Multicallable {
    using LibString for uint256;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when tokens are lazy minted.
    event TokensLazyMinted(
        address indexed token, uint256 indexed startTokenId, uint256 endTokenId, string baseURI, bytes encryptedBaseURI
    );

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when caller is not token core admin.
    error LazyMintHookNotAuthorized();

    /// @notice Emitted when querying an invalid index in a batch array.
    error LazyMintHookInvalidIndex();

    /// @notice Emitted when lazy minting zero tokens.
    error LazyMintHookZeroAmount();

    /// @notice Emitted when querying URI for a non-existent invalid token ID.
    error LazyMintHookInvalidTokenId();

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Returns all hooks implemented by the contract and all hook contract functions to register as
     *          callable via core contract fallback function.
     */
    function getHookInfo() external pure returns (HookInfo memory hookInfo) {
        hookInfo.hookFlags = ON_TOKEN_URI_FLAG;
        hookInfo.hookFallbackFunctions = new HookFallbackFunction[](3);
        hookInfo.hookFallbackFunctions[0] =
            HookFallbackFunction(this.getBaseURICount.selector, CallType.STATICCALL, false);
        hookInfo.hookFallbackFunctions[1] =
            HookFallbackFunction(this.getBatchIdAtIndex.selector, CallType.STATICCALL, false);
        hookInfo.hookFallbackFunctions[2] = HookFallbackFunction(this.lazyMint.selector, CallType.CALL, true);
    }

    /**
     *  @notice Returns the count of batches of NFTs for a token.
     *  @param _token The token address.
     */
    function getBaseURICount(address _token) public view returns (uint256) {
        return _lazyMintStorage().batchIds[_token].length;
    }

    /**
     *  @notice Returns the URI to fetch token metadata from.
     *  @dev Meant to be called by the core token contract.
     *  @param _id The token ID of the NFT.
     */
    function onTokenURI(uint256 _id) public view override returns (string memory) {
        address token = msg.sender;
        string memory batchUri = _getBaseURI(token, _id);

        return string(abi.encodePacked(batchUri, _id.toString()));
    }

    /**
     *  @notice Returns the ID for the batch of tokens at the given index.
     *  @param _token The token address.
     *  @param _index The index of the batch.
     */
    function getBatchIdAtIndex(address _token, uint256 _index) public view returns (uint256) {
        if (_index >= getBaseURICount(_token)) {
            revert LazyMintHookInvalidIndex();
        }
        return _lazyMintStorage().batchIds[_token][_index];
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Lazy mints a given amount of NFTs.
     *  @param _amount The number of NFTs to lazy mint.
     *  @param _baseURIForTokens Base URI for a batch of NFTs.
     *  @param _data Additional bytes data
     *  @return batchId A unique integer identifier for the batch of NFTs lazy minted together.
     */
    function lazyMint(uint256 _amount, string calldata _baseURIForTokens, bytes calldata _data)
        public
        virtual
        returns (uint256 batchId)
    {
        address token = msg.sender;
        if (_amount == 0) {
            revert LazyMintHookZeroAmount();
        }

        uint256 startId = _lazyMintStorage().nextTokenIdToLazyMint[token];
        (_lazyMintStorage().nextTokenIdToLazyMint[token], batchId) =
            _batchMintMetadata(token, startId, _amount, _baseURIForTokens);

        emit TokensLazyMinted(token, startId, startId + _amount - 1, _baseURIForTokens, _data);

        return batchId;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Mints a batch of tokenIds and associates a common baseURI to all those Ids.
    function _batchMintMetadata(
        address _token,
        uint256 _startId,
        uint256 _amountToMint,
        string memory _baseURIForTokens
    ) internal returns (uint256 nextTokenIdToMint, uint256 batchId) {
        batchId = _startId + _amountToMint;
        nextTokenIdToMint = batchId;

        _lazyMintStorage().batchIds[_token].push(batchId);
        _lazyMintStorage().baseURI[_token][batchId] = _baseURIForTokens;
    }

    /// @dev Returns the baseURI for a token. The intended metadata URI for the token is baseURI + tokenId.
    function _getBaseURI(address _token, uint256 _tokenId) internal view returns (string memory) {
        uint256 numOfTokenBatches = getBaseURICount(_token);

        uint256[] memory indices = _lazyMintStorage().batchIds[_token];

        for (uint256 i = 0; i < numOfTokenBatches; i += 1) {
            if (_tokenId < indices[i]) {
                return _lazyMintStorage().baseURI[_token][indices[i]];
            }
        }
        revert LazyMintHookInvalidTokenId();
    }

    function _lazyMintStorage() internal pure returns (LazyMintStorage.Data storage) {
        return LazyMintStorage.data();
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../../interface/extension/IPermission.sol";

import { NFTHook } from "../../extension/NFTHook.sol";
import { LibString } from "../../lib/LibString.sol";

contract LazyMintMetadataHook is NFTHook {

    using LibString for uint256;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant ADMIN_ROLE_BITS = 2 ** 1;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event TokensLazyMinted(address indexed token, uint256 indexed startTokenId, uint256 endTokenId, string baseURI, bytes encryptedBaseURI);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint256[]) private _batchIds;
    mapping(address => uint256) private _nextTokenIdToLazyMint;
    mapping(address => mapping(uint256 => string)) private _baseURI;

    /*//////////////////////////////////////////////////////////////
                               MODIFIER
    //////////////////////////////////////////////////////////////*/

    modifier onlyAdmin(address _token) {
        require(IPermission(_token).hasRole(msg.sender, ADMIN_ROLE_BITS), "not authorized");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getHooksImplemented() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = TOKEN_URI_FLAG;
    }

    function getBaseURICount(address _token) public view returns (uint256) {
        return _batchIds[_token].length;
    }

    /// @notice Returns the URI to fetch token metadata from.
    function tokenURI(uint256 id) external view returns (string memory) {
        address token = msg.sender;
        string memory batchUri = _getBaseURI(token, id);

        return string(abi.encodePacked(batchUri, id.toString()));
    }

    function getBatchIdAtIndex(address _token, uint256 _index) public view returns (uint256) {
        if (_index >= getBaseURICount(_token)) {
            revert("Invalid index");
        }
        return _batchIds[_token][_index];
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function lazyMint(
        address _token,
        uint256 _amount,
        string calldata _baseURIForTokens,
        bytes calldata _data
    ) public virtual onlyAdmin(_token) returns (uint256 batchId) {
        if (_amount == 0) {
            revert("0 amt");
        }

        uint256 startId = _nextTokenIdToLazyMint[_token];

        (_nextTokenIdToLazyMint[_token], batchId) = _batchMintMetadata(_token, startId, _amount, _baseURIForTokens);

        emit TokensLazyMinted(_token, startId, startId + _amount - 1, _baseURIForTokens, _data);

        return batchId;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _batchMintMetadata(
        address _token,
        uint256 _startId,
        uint256 _amountToMint,
        string memory _baseURIForTokens
    ) internal returns (uint256 nextTokenIdToMint, uint256 batchId) {
        batchId = _startId + _amountToMint;
        nextTokenIdToMint = batchId;

        _batchIds[_token].push(batchId);

        _baseURI[_token][batchId] = _baseURIForTokens;
    }

    function _getBaseURI(address _token, uint256 _tokenId) internal view returns (string memory) {
        uint256 numOfTokenBatches = getBaseURICount(_token);
        uint256[] memory indices = _batchIds[_token];

        for (uint256 i = 0; i < numOfTokenBatches; i += 1) {
            if (_tokenId < indices[i]) {
                return _baseURI[_token][indices[i]];
            }
        }
        revert("Invalid tokenId");
    }
}
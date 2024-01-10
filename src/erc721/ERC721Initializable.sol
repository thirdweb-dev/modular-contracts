// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import { Initializable } from  "../extension/Initializable.sol";
import { IERC721 } from "../interface/erc721/IERC721.sol";
import { IERC721Supply } from "../interface/erc721/IERC721Supply.sol";
import { IERC721Metadata } from "../interface/erc721/IERC721Metadata.sol";
import { IERC721CustomErrors } from "../interface/erc721/IERC721CustomErrors.sol";
import { IERC721Receiver } from "../interface/erc721/IERC721Receiver.sol";
import { IERC2981 } from "../interface/eip/IERC2981.sol";

contract ERC721Initializable is Initializable, IERC721, IERC721Supply, IERC721Metadata, IERC721CustomErrors, IERC2981 {

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @dev An struct for internal use. Stores a token's owner and metadata source.
    struct TokenData {
        address owner;
        address metadataSource;
    }

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The name of the token collection.
    string public name;

    /// @notice The symbol of the token collection.
    string public symbol;

    /**
     *  @notice The total circulating supply of NFTs.
     *  @dev Initialized as `1` in `initialize` to save on `mint` gas.
     */
    uint256 private _totalSupply;

    /// @notice Mapping from token ID to TokenData i.e. owner and metadata source.
    mapping(uint256 => TokenData) private _tokenData;
    
    /// @notice Mapping from owner address to number of owned token.
    mapping(address => uint256) private _balanceOf;

    /// @notice Mapping from token ID to approved spender address.
    mapping(uint256 => address) public getApproved;

    /// @notice Mapping from owner to operator approvals.
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract with collection name and symbol.
    function __ERC721_init(string memory _name, string memory _symbol) internal onlyInitializing {
        name = _name;
        symbol = _symbol;
        _totalSupply = 1;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Returns the token metadata of an NFT.
     *  @dev Always returns metadata queried from the metadata source.
     *  @param _id The token ID of the NFT.
     *  @return metadata The URI to fetch metadata from.
     */
    function tokenURI(uint256 _id) public view virtual returns (string memory metadata) {
        return IERC721Metadata(_tokenData[_id].metadataSource).tokenURI(_id);
    }

    /**
     *  @notice Returns the metadata source of an NFT.
     *  @dev The metadata source of an NFT is set at minting time, and does not change later.
     *  @param _id The token ID of the NFT.
     *  @return metadataSource The address of the metadata source.
     */
    function metadataSourceOf(uint256 _id) public view virtual returns (address) {
        return _tokenData[_id].metadataSource;
    }

    /**
     *  @notice Returns the owner of an NFT.
     *  @dev Throws if the NFT does not exist.
     *  @param _id The token ID of the NFT.
     *  @return owner The address of the owner of the NFT.
     */
    function ownerOf(uint256 _id) public view virtual returns (address owner) {
        if((owner = _tokenData[_id].owner) == address(0)) {
            revert ERC721NotMinted(_id);
        }
    }
    
    /**
     *  @notice Returns the total quantity of NFTs owned by an address.
     *  @param _owner The address to query the balance of
     *  @return balance The number of NFTs owned by the queried address
     */
    function balanceOf(address _owner) public view virtual returns (uint256) {
        return _balanceOf[_owner];
    }

    /**
     *  @notice Returns the total circulating supply of NFTs.
     *  @return supply The total circulating supply of NFTs
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply - 1; // We initialize totalSupply as `1` in `initialize` to save on `mint` gas.
    }

    /**
     *  @notice Returns the royalty amount for a given NFT and sale price.
     *  @param _tokenId The token ID of the NFT
     *  @param _salePrice The sale price of the NFT
     *  @return receiver The royalty recipient address
     *  @return royaltyAmount The royalty amount to send to the recipient as part of a sale
     */
    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view returns (address, uint256) {
        return IERC2981(_tokenData[_tokenId].metadataSource).royaltyInfo(_tokenId, _salePrice);
    }

    /**
     *  @notice Returns whether the contract implements an interface with the given interface ID.
     *  @param _interfaceId The interface ID of the interface to check for
     */
    function supportsInterface(bytes4 _interfaceId) public view virtual returns (bool) {
        return
            _interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            _interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            _interfaceId == 0x5b5e139f || // ERC165 Interface ID for ERC721Metadata
            _interfaceId == 0x2a55205a; // ERC165 Interface ID for ERC-2981
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Approves an address to transfer a specific NFT. Reverts if caller is not owner or approved operator.
     *  @param _spender The address to approve
     *  @param _id The token ID of the NFT
     */
    function approve(address _spender, uint256 _id) public virtual {
        address owner = _tokenData[_id].owner;

        if(msg.sender != owner && !isApprovedForAll[owner][msg.sender]) {
            revert ERC721NotApproved(msg.sender, _id);
        }

        getApproved[_id] = _spender;

        emit Approval(owner, _spender, _id);
    }

    /**
     *  @notice Approves or revokes approval from an operator to transfer or issue approval for all of the caller's NFTs.
     *  @param _operator The address to approve or revoke approval from
     *  @param _approved Whether the operator is approved
     */
    function setApprovalForAll(address _operator, bool _approved) public virtual {
        isApprovedForAll[msg.sender][_operator] = _approved;

        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /**
     *  @notice Transfers ownership of an NFT from one address to another.
     *  @param _from The address to transfer from
     *  @param _to The address to transfer to
     *  @param _id The token ID of the NFT
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _id
    ) public virtual {
        if(_from != _tokenData[_id].owner) {
            revert ERC721NotOwner(_from, _id);
        }

        if(_to == address(0)) {
            revert ERC721InvalidRecipient();
        }

        if(msg.sender != _from && !isApprovedForAll[_from][msg.sender] && msg.sender != getApproved[_id]) {
            revert ERC721NotApproved(msg.sender, _id);
        }

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        unchecked {
            _balanceOf[_from]--;

            _balanceOf[_to]++;
        }

        _tokenData[_id].owner = _to;

        delete getApproved[_id];

        emit Transfer(_from, _to, _id);
    }

    /**
     *  @notice Transfers ownership of an NFT from one address to another. If transfer is recipient is a smart contract,
     *          checks if recipient implements ERC721Receiver interface and calls the `onERC721Received` function.
     *  @param _from The address to transfer from
     *  @param _to The address to transfer to
     *  @param _id The token ID of the NFT
     */
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id
    ) public virtual {
        transferFrom(_from, _to, _id);

        if(
            _to.code.length != 0 
                && IERC721Receiver(_to).onERC721Received(msg.sender, _from, _id, "") != IERC721Receiver.onERC721Received.selector
        ) {
            revert ERC721UnsafeRecipient(_to);
        }
        
    }

    /**
     *  @notice Transfers ownership of an NFT from one address to another. If transfer is recipient is a smart contract,
     *          checks if recipient implements ERC721Receiver interface and calls the `onERC721Received` function.
     *  @param _from The address to transfer from
     *  @param _to The address to transfer to
     *  @param _id The token ID of the NFT
     *  @param _data Additional data passed onto the `onERC721Received` call to the recipient
     */
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        bytes calldata _data
    ) public virtual {
        transferFrom(_from, _to, _id);

        if(
            _to.code.length != 0 
                && IERC721Receiver(_to).onERC721Received(msg.sender, _from, _id, _data) != IERC721Receiver.onERC721Received.selector
        ) {
            revert ERC721UnsafeRecipient(_to);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @dev Mints a given quantity of NFTs to an owner address
     *  @param _to The address to mint NFTs to
     *  @param _startId The token ID of the first NFT to mint
     *  @param _quantity The quantity of NFTs to mint
     *  @param _metadataSource The address of the metadata source of all the minted NFTs
     */
    function _mint(address _to, uint256 _startId, uint256 _quantity, address _metadataSource) internal virtual {
        if(_to == address(0)) {
            revert ERC721InvalidRecipient();
        }

        uint256 endId = _startId + _quantity;

        // Counter overflow is incredibly unrealistic.
        unchecked {
            _balanceOf[_to] += _quantity;
            _totalSupply += _quantity;
        }

        for(uint256 id = _startId; id < endId; id++) {
            if(_tokenData[id].owner != address(0)) {
                revert ERC721AlreadyMinted(id);
            }

            _tokenData[id] = TokenData(_to, _metadataSource);

            emit Transfer(address(0), _to, id);
        }
    }

    /**
     *  @dev Burns an NFT
     *  @param _id The token ID of the NFT to burn
     */
    function _burn(uint256 _id) internal virtual {
        address owner = _tokenData[_id].owner;

        if(owner == address(0)) {
            revert ERC721NotMinted(_id);
        }

        // Ownership check above ensures no underflow.
        unchecked {
            _balanceOf[owner]--;
            _totalSupply--;
        }

        delete _tokenData[_id].owner;

        delete getApproved[_id];

        emit Transfer(owner, address(0), _id);
    }
}

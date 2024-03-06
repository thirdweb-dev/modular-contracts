// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Initializable} from "@solady/utils/Initializable.sol";

import {IERC721} from "../../interface/eip/IERC721.sol";
import {IERC721Supply} from "../../interface/eip/IERC721Supply.sol";
import {IERC721Metadata} from "../../interface/eip/IERC721Metadata.sol";
import {IERC721Receiver} from "../../interface/eip/IERC721Receiver.sol";
import {IERC2981} from "../../interface/eip/IERC2981.sol";

abstract contract ERC721Initializable is Initializable, IERC721, IERC721Supply, IERC721Metadata, IERC2981 {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on an attempt to burn or query ownership of an unminted token.
    error ERC721NotMinted(uint256 tokenId);

    /// @notice Emitted on an attempt to mint a token that has already been minted.
    error ERC721AlreadyMinted(uint256 tokenId);

    /// @notice Emitted when an unapproved operator attempts to transfer or issue approval for a token.
    error ERC721NotApproved(address operator, uint256 tokenId);

    /// @notice Emitted on an attempt to transfer a token from non-owner's address.
    error ERC721NotOwner(address caller, uint256 tokenId);

    /// @notice Emitted on an attempt to mint or transfer a token to the zero address.
    error ERC721InvalidRecipient();

    /// @notice Emitted on an attempt to transfer a token to a contract not implementing ERC-721 Receiver interface.
    error ERC721UnsafeRecipient(address recipient);

    /// @notice Revert for zero address param
    error ERC721ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The name of the token collection.
    string private name_;
    /// @notice The symbol of the token collection.
    string private symbol_;
    /**
     *  @notice The total circulating supply of NFTs.
     *  @dev Initialized as `1` in `initialize` to save on `mint` gas.
     */
    uint256 private totalSupply_;
    /// @notice Mapping from token ID to TokenData i.e. owner and metadata source.
    mapping(uint256 => address) private ownerOf_;
    /// @notice Mapping from owner address to number of owned token.
    mapping(address => uint256) private balanceOf_;
    /// @notice Mapping from token ID to approved spender address.
    mapping(uint256 => address) private getApproved_;
    /// @notice Mapping from owner to operator approvals.
    mapping(address => mapping(address => bool)) private isApprovedForAll_;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract with collection name and symbol.
    function __ERC721_init(string memory _name, string memory _symbol) internal onlyInitializing {
        name_ = _name;
        symbol_ = _symbol;
        totalSupply_ = 1;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice The name of the token.
    function name() public view virtual override returns (string memory) {
        return name_;
    }

    /// @notice The symbol of the token.
    function symbol() public view virtual override returns (string memory) {
        return symbol_;
    }

    /// @notice Returns the address of the approved spender of a token.
    function getApproved(uint256 _id) public view virtual override returns (address) {
        return getApproved_[_id];
    }

    /// @notice Returns whether the caller is approved to transfer any of the owner's NFTs.
    function isApprovedForAll(address _owner, address _operator) public view virtual override returns (bool) {
        return isApprovedForAll_[_owner][_operator];
    }

    /**
     *  @notice Returns the owner of an NFT.
     *  @dev Throws if the NFT does not exist.
     *  @param _id The token ID of the NFT.
     *  @return owner The address of the owner of the NFT.
     */
    function ownerOf(uint256 _id) public view virtual returns (address owner) {
        if ((owner = ownerOf_[_id]) == address(0)) {
            revert ERC721NotMinted(_id);
        }
    }

    /**
     *  @notice Returns the total quantity of NFTs owned by an address.
     *  @param _owner The address to query the balance of
     *  @return balance The number of NFTs owned by the queried address
     */
    function balanceOf(address _owner) public view virtual returns (uint256) {
        if (_owner == address(0)) {
            revert ERC721ZeroAddress();
        }
        return balanceOf_[_owner];
    }

    /**
     *  @notice Returns the total circulating supply of NFTs.
     *  @return supply The total circulating supply of NFTs
     */
    function totalSupply() public view virtual returns (uint256) {
        return totalSupply_ - 1; // We initialize totalSupply as `1` in `initialize` to save on `mint` gas.
    }

    /**
     *  @notice Returns whether the contract implements an interface with the given interface ID.
     *  @param _interfaceId The interface ID of the interface to check for
     */
    function supportsInterface(bytes4 _interfaceId) public view virtual returns (bool) {
        return _interfaceId == 0x01ffc9a7 // ERC165 Interface ID for ERC165
            || _interfaceId == 0x80ac58cd; // ERC165 Interface ID for ERC721
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
        address owner = ownerOf_[_id];

        if (msg.sender != owner && !isApprovedForAll_[owner][msg.sender]) {
            revert ERC721NotApproved(msg.sender, _id);
        }

        getApproved_[_id] = _spender;

        emit Approval(owner, _spender, _id);
    }

    /**
     *  @notice Approves or revokes approval from an operator to transfer or issue approval for all of the caller's NFTs.
     *  @param _operator The address to approve or revoke approval from
     *  @param _approved Whether the operator is approved
     */
    function setApprovalForAll(address _operator, bool _approved) public virtual {
        isApprovedForAll_[msg.sender][_operator] = _approved;

        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /**
     *  @notice Transfers ownership of an NFT from one address to another.
     *  @param _from The address to transfer from
     *  @param _to The address to transfer to
     *  @param _id The token ID of the NFT
     */
    function transferFrom(address _from, address _to, uint256 _id) public virtual {
        if (_from != ownerOf_[_id]) {
            revert ERC721NotOwner(_from, _id);
        }

        if (_to == address(0)) {
            revert ERC721InvalidRecipient();
        }

        if (msg.sender != _from && !isApprovedForAll_[_from][msg.sender] && msg.sender != getApproved_[_id]) {
            revert ERC721NotApproved(msg.sender, _id);
        }

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        unchecked {
            balanceOf_[_from]--;

            balanceOf_[_to]++;
        }

        ownerOf_[_id] = _to;

        delete getApproved_[_id];

        emit Transfer(_from, _to, _id);
    }

    /**
     *  @notice Transfers ownership of an NFT from one address to another. If transfer is recipient is a smart contract,
     *          checks if recipient implements ERC721Receiver interface and calls the `onERC721Received` function.
     *  @param _from The address to transfer from
     *  @param _to The address to transfer to
     *  @param _id The token ID of the NFT
     */
    function safeTransferFrom(address _from, address _to, uint256 _id) public virtual {
        transferFrom(_from, _to, _id);

        if (
            _to.code.length != 0
                && IERC721Receiver(_to).onERC721Received(msg.sender, _from, _id, "")
                    != IERC721Receiver.onERC721Received.selector
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
    function safeTransferFrom(address _from, address _to, uint256 _id, bytes calldata _data) public virtual {
        transferFrom(_from, _to, _id);

        if (
            _to.code.length != 0
                && IERC721Receiver(_to).onERC721Received(msg.sender, _from, _id, _data)
                    != IERC721Receiver.onERC721Received.selector
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
     */
    function _mint(address _to, uint256 _startId, uint256 _quantity) internal virtual {
        if (_to == address(0)) {
            revert ERC721InvalidRecipient();
        }

        uint256 endId = _startId + _quantity;

        // Counter overflow is incredibly unrealistic.
        unchecked {
            balanceOf_[_to] += _quantity;
            totalSupply_ += _quantity;
        }

        for (uint256 id = _startId; id < endId; id++) {
            if (ownerOf_[id] != address(0)) {
                revert ERC721AlreadyMinted(id);
            }

            ownerOf_[id] = _to;

            emit Transfer(address(0), _to, id);
        }
    }

    /**
     *  @dev Burns an NFT
     *  @param _id The token ID of the NFT to burn
     */
    function _burn(uint256 _id) internal virtual {
        address owner = ownerOf_[_id];

        if (owner == address(0)) {
            revert ERC721NotMinted(_id);
        }

        // Ownership check above ensures no underflow.
        unchecked {
            balanceOf_[owner]--;
            totalSupply_--;
        }

        delete ownerOf_[_id];
        delete getApproved_[_id];

        emit Transfer(owner, address(0), _id);
    }
}

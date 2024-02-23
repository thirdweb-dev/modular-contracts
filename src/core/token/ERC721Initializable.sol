// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import { Initializable } from "@solady/utils/Initializable.sol";

import { IERC721 } from "../../interface/eip/IERC721.sol";
import { IERC721Supply } from "../../interface/eip/IERC721Supply.sol";
import { IERC721Metadata } from "../../interface/eip/IERC721Metadata.sol";
import { IERC721CustomErrors } from "../../interface/errors/IERC721CustomErrors.sol";
import { IERC721Receiver } from "../../interface/eip/IERC721Receiver.sol";
import { IERC2981 } from "../../interface/eip/IERC2981.sol";

import { ERC721InitializableStorage } from "../../storage/core/ERC721InitializableStorage.sol";

abstract contract ERC721Initializable is
    Initializable,
    IERC721,
    IERC721Supply,
    IERC721Metadata,
    IERC721CustomErrors,
    IERC2981
{
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract with collection name and symbol.
    function __ERC721_init(string memory _name, string memory _symbol) internal onlyInitializing {
        ERC721InitializableStorage.Data storage data = ERC721InitializableStorage.data();

        data.name = _name;
        data.symbol = _symbol;
        data.totalSupply = 1;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice The name of the token.
    function name() public view virtual override returns (string memory) {
        return ERC721InitializableStorage.data().name;
    }

    /// @notice The symbol of the token.
    function symbol() public view virtual override returns (string memory) {
        return ERC721InitializableStorage.data().symbol;
    }

    /// @notice Returns the address of the approved spender of a token.
    function getApproved(uint256 _id) public view virtual override returns (address) {
        return ERC721InitializableStorage.data().getApproved[_id];
    }

    /// @notice Returns whether the caller is approved to transfer any of the owner's NFTs.
    function isApprovedForAll(address _owner, address _operator) public view virtual override returns (bool) {
        return ERC721InitializableStorage.data().isApprovedForAll[_owner][_operator];
    }

    /**
     *  @notice Returns the owner of an NFT.
     *  @dev Throws if the NFT does not exist.
     *  @param _id The token ID of the NFT.
     *  @return owner The address of the owner of the NFT.
     */
    function ownerOf(uint256 _id) public view virtual returns (address owner) {
        if ((owner = ERC721InitializableStorage.data().ownerOf[_id]) == address(0)) {
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
        return ERC721InitializableStorage.data().balanceOf[_owner];
    }

    /**
     *  @notice Returns the total circulating supply of NFTs.
     *  @return supply The total circulating supply of NFTs
     */
    function totalSupply() public view virtual returns (uint256) {
        return ERC721InitializableStorage.data().totalSupply - 1; // We initialize totalSupply as `1` in `initialize` to save on `mint` gas.
    }

    /**
     *  @notice Returns whether the contract implements an interface with the given interface ID.
     *  @param _interfaceId The interface ID of the interface to check for
     */
    function supportsInterface(bytes4 _interfaceId) public view virtual returns (bool) {
        return
            _interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            _interfaceId == 0x80ac58cd; // ERC165 Interface ID for ERC721
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
        ERC721InitializableStorage.Data storage data = ERC721InitializableStorage.data();
        address owner = data.ownerOf[_id];

        if (msg.sender != owner && !data.isApprovedForAll[owner][msg.sender]) {
            revert ERC721NotApproved(msg.sender, _id);
        }

        data.getApproved[_id] = _spender;

        emit Approval(owner, _spender, _id);
    }

    /**
     *  @notice Approves or revokes approval from an operator to transfer or issue approval for all of the caller's NFTs.
     *  @param _operator The address to approve or revoke approval from
     *  @param _approved Whether the operator is approved
     */
    function setApprovalForAll(address _operator, bool _approved) public virtual {
        ERC721InitializableStorage.data().isApprovedForAll[msg.sender][_operator] = _approved;

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
        ERC721InitializableStorage.Data storage data = ERC721InitializableStorage.data();

        if (_from != data.ownerOf[_id]) {
            revert ERC721NotOwner(_from, _id);
        }

        if (_to == address(0)) {
            revert ERC721InvalidRecipient();
        }

        if (msg.sender != _from && !data.isApprovedForAll[_from][msg.sender] && msg.sender != data.getApproved[_id]) {
            revert ERC721NotApproved(msg.sender, _id);
        }

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        unchecked {
            data.balanceOf[_from]--;

            data.balanceOf[_to]++;
        }

        data.ownerOf[_id] = _to;

        delete data.getApproved[_id];

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

        if (
            _to.code.length != 0 &&
            IERC721Receiver(_to).onERC721Received(msg.sender, _from, _id, "") !=
            IERC721Receiver.onERC721Received.selector
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

        if (
            _to.code.length != 0 &&
            IERC721Receiver(_to).onERC721Received(msg.sender, _from, _id, _data) !=
            IERC721Receiver.onERC721Received.selector
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
    function _mint(
        address _to,
        uint256 _startId,
        uint256 _quantity
    ) internal virtual {
        if (_to == address(0)) {
            revert ERC721InvalidRecipient();
        }

        uint256 endId = _startId + _quantity;

        ERC721InitializableStorage.Data storage data = ERC721InitializableStorage.data();

        // Counter overflow is incredibly unrealistic.
        unchecked {
            data.balanceOf[_to] += _quantity;
            data.totalSupply += _quantity;
        }

        for (uint256 id = _startId; id < endId; id++) {
            if (data.ownerOf[id] != address(0)) {
                revert ERC721AlreadyMinted(id);
            }

            data.ownerOf[id] = _to;

            emit Transfer(address(0), _to, id);
        }
    }

    /**
     *  @dev Burns an NFT
     *  @param _id The token ID of the NFT to burn
     */
    function _burn(uint256 _id) internal virtual {
        ERC721InitializableStorage.Data storage data = ERC721InitializableStorage.data();

        address owner = data.ownerOf[_id];

        if (owner == address(0)) {
            revert ERC721NotMinted(_id);
        }

        // Ownership check above ensures no underflow.
        unchecked {
            data.balanceOf[owner]--;
            data.totalSupply--;
        }

        delete data.ownerOf[_id];
        delete data.getApproved[_id];

        emit Transfer(owner, address(0), _id);
    }
}

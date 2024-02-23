// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import { Initializable } from "@solady/utils/Initializable.sol";

import { IERC1155 } from "../../interface/eip/IERC1155.sol";
import { IERC1155Supply } from "../../interface/eip/IERC1155Supply.sol";
import { IERC1155MetadataURI } from "../../interface/eip/IERC1155Metadata.sol";
import { IERC1155CustomErrors } from "../../interface/errors/IERC1155CustomErrors.sol";
import { IERC1155Receiver } from "../../interface/eip/IERC1155Receiver.sol";
import { IERC2981 } from "../../interface/eip/IERC2981.sol";

import { ERC1155InitializableStorage } from "../../storage/core/ERC1155InitializableStorage.sol";

abstract contract ERC1155Initializable is
    Initializable,
    IERC1155,
    IERC1155Supply,
    IERC1155MetadataURI,
    IERC1155CustomErrors,
    IERC2981
{
    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract with collection name and symbol.
    function __ERC1155_init(string memory _name, string memory _symbol) internal onlyInitializing {
        ERC1155InitializableStorage.Data storage data = ERC1155InitializableStorage.data();

        data.name = _name;
        data.symbol = _symbol;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice The name of the token.
    function name() public view virtual returns (string memory) {
        return ERC1155InitializableStorage.data().name;
    }

    /// @notice The symbol of the token.
    function symbol() public view virtual returns (string memory) {
        return ERC1155InitializableStorage.data().symbol;
    }

    /// @notice Returns whether an operator is approved to transfer any NFTs of the owner.
    function isApprovedForAll(address _owner, address _operator) public view virtual override returns (bool) {
        return ERC1155InitializableStorage.data().isApprovedForAll[_owner][_operator];
    }

    /**
     *  @notice Returns the total quantity of NFTs owned by an address.
     *  @param _owner The address to query the balance of
     *  @return balance The number of NFTs owned by the queried address
     */
    function balanceOf(address _owner, uint256 _tokenId) public view virtual returns (uint256) {
        return ERC1155InitializableStorage.data().balanceOf[_owner][_tokenId];
    }

    function balanceOfBatch(address[] calldata _owners, uint256[] calldata _tokenIds)
        external
        view
        returns (uint256[] memory _balances)
    {
        ERC1155InitializableStorage.Data storage data = ERC1155InitializableStorage.data();

        if (_owners.length != _tokenIds.length) {
            revert ERC1155ArrayLengthMismatch();
        }

        _balances = new uint256[](_owners.length);

        // Unchecked because the only math done is incrementing
        // the array index counter which cannot possibly overflow.
        unchecked {
            for (uint256 i = 0; i < _owners.length; ++i) {
                _balances[i] = data.balanceOf[_owners[i]][_tokenIds[i]];
            }
        }
    }

    /**
     *  @notice Returns the total circulating supply of NFTs.
     *  @return supply The total circulating supply of NFTs
     */
    function totalSupply(uint256 _tokenId) public view virtual returns (uint256) {
        return ERC1155InitializableStorage.data().totalSupply[_tokenId];
    }

    /**
     *  @notice Returns whether the contract implements an interface with the given interface ID.
     *  @param _interfaceId The interface ID of the interface to check for
     */
    function supportsInterface(bytes4 _interfaceId) public view virtual returns (bool) {
        return
            _interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            _interfaceId == 0xd9b67a26 || // ERC165 Interface ID for ERC1155
            _interfaceId == 0x0e89341c; // ERC165 Interface ID for ERC1155MetadataURI
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Approves or revokes approval from an operator to transfer or issue approval for all of the caller's NFTs.
     *  @param _operator The address to approve or revoke approval from
     *  @param _approved Whether the operator is approved
     */
    function setApprovalForAll(address _operator, bool _approved) public virtual {
        ERC1155InitializableStorage.data().isApprovedForAll[msg.sender][_operator] = _approved;

        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /**
     *  @notice Transfers ownership of an NFT from one address to another. If transfer is recipient is a smart contract,
     *          checks if recipient implements ERC1155Receiver interface and calls the `onERC1155Received` function.
     *  @param _from The address to transfer from
     *  @param _to The address to transfer to
     *  @param _tokenId The token ID of the NFT
     *  @param _value Total number of NFTs with that id
     *  @param _data data
     */
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 _value,
        bytes calldata _data
    ) public virtual {
        ERC1155InitializableStorage.Data storage data = ERC1155InitializableStorage.data();

        if (msg.sender != _from && !data.isApprovedForAll[_from][msg.sender]) {
            revert ERC1155NotApprovedOrOwner(msg.sender);
        }

        data.balanceOf[_from][_tokenId] -= _value;
        data.balanceOf[_to][_tokenId] += _value;

        emit TransferSingle(msg.sender, _from, _to, _tokenId, _value);

        if (
            _to.code.length == 0
                ? _to == address(0)
                : IERC1155Receiver(_to).onERC1155Received(msg.sender, _from, _tokenId, _value, _data) !=
                    IERC1155Receiver.onERC1155Received.selector
        ) {
            revert ERC1155UnsafeRecipient(_to);
        }
    }

    /**
     *  @notice Transfers ownership of tokens from one address to another. If transfer is recipient is a smart contract,
     *          checks if recipient implements ERC1155Receiver interface and calls the `onERC1155Received` function.
     *  @param _from The address to transfer from
     *  @param _to The address to transfer to
     *  @param _tokenIds The token IDs of the NFT
     *  @param _values Total amounts of NFTs with those ids
     *  @param _data data
     */
    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _tokenIds,
        uint256[] calldata _values,
        bytes calldata _data
    ) public virtual {
        if (_tokenIds.length != _values.length) {
            revert ERC1155ArrayLengthMismatch();
        }

        ERC1155InitializableStorage.Data storage data = ERC1155InitializableStorage.data();
        if (msg.sender != _from && !data.isApprovedForAll[_from][msg.sender]) {
            revert ERC1155NotApprovedOrOwner(msg.sender);
        }

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 value;

        for (uint256 i = 0; i < _tokenIds.length; ) {
            id = _tokenIds[i];
            value = _values[i];

            data.balanceOf[_from][id] -= value;
            data.balanceOf[_to][id] += value;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, _from, _to, _tokenIds, _values);

        if (
            _to.code.length == 0
                ? _to == address(0)
                : IERC1155Receiver(_to).onERC1155BatchReceived(msg.sender, _from, _tokenIds, _values, _data) !=
                    IERC1155Receiver.onERC1155BatchReceived.selector
        ) {
            revert ERC1155UnsafeRecipient(_to);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _mint(
        address _to,
        uint256 _tokenId,
        uint256 _value,
        bytes memory _data
    ) internal virtual {
        ERC1155InitializableStorage.data().balanceOf[_to][_tokenId] += _value;
        ERC1155InitializableStorage.data().totalSupply[_tokenId] += _value;

        emit TransferSingle(msg.sender, address(0), _to, _tokenId, _value);

        if (
            _to.code.length == 0
                ? _to == address(0)
                : IERC1155Receiver(_to).onERC1155Received(msg.sender, address(0), _tokenId, _value, _data) !=
                    IERC1155Receiver.onERC1155Received.selector
        ) {
            revert ERC1155UnsafeRecipient(_to);
        }
    }

    function _burn(
        address _from,
        uint256 _tokenId,
        uint256 _value
    ) internal virtual {
        if (_from == address(0)) {
            revert ERC1155BurnFromZeroAddress();
        }

        ERC1155InitializableStorage.Data storage data = ERC1155InitializableStorage.data();

        uint256 balance = data.balanceOf[_from][_tokenId];

        if (balance < _value) {
            revert ERC1155NotBalance(_from, _tokenId, _value);
        }

        unchecked {
            data.balanceOf[_from][_tokenId] -= _value;
            data.totalSupply[_tokenId] -= _value;
        }

        emit TransferSingle(msg.sender, _from, address(0), _tokenId, _value);
    }
}

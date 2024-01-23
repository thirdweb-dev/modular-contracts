// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import { Initializable } from "../extension/Initializable.sol";
import { IERC1155 } from "../interface/erc1155/IERC1155.sol";
import { IERC1155Supply } from "../interface/erc1155/IERC1155Supply.sol";
import { IERC1155MetadataURI } from "../interface/erc1155/IERC1155Metadata.sol";
import { IERC1155CustomErrors } from "../interface/erc1155/IERC1155CustomErrors.sol";
import { IERC1155Receiver } from "../interface/erc1155/IERC1155Receiver.sol";
import { IERC2981 } from "../interface/eip/IERC2981.sol";

abstract contract ERC1155Initializable is
  Initializable,
  IERC1155,
  IERC1155Supply,
  IERC1155MetadataURI,
  IERC1155CustomErrors,
  IERC2981
{
  /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

  /// @notice The name of the token collection.
  string public name;

  /// @notice The symbol of the token collection.
  string public symbol;

  /**
   *  @notice Token ID => total circulating supply of tokens with that ID.
   */
  mapping(uint256 => uint256) private _totalSupply;

  /// @notice Mapping from owner address to ID to amount of owned tokens with that ID.
  mapping(address => mapping(uint256 => uint256)) private _balanceOf;

  /// @notice Mapping from owner to operator approvals.
  mapping(address => mapping(address => bool)) public isApprovedForAll;

  /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

  constructor() {
    _disableInitializers();
  }

  /// @dev Initializes the contract with collection name and symbol.
  function __ERC1155_init(
    string memory _name,
    string memory _symbol
  ) internal onlyInitializing {
    name = _name;
    symbol = _symbol;
  }

  /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  /**
   *  @notice Returns the total quantity of NFTs owned by an address.
   *  @param _owner The address to query the balance of
   *  @return balance The number of NFTs owned by the queried address
   */
  function balanceOf(
    address _owner,
    uint256 _id
  ) public view virtual returns (uint256) {
    return _balanceOf[_owner][_id];
  }

  function balanceOfBatch(
    address[] calldata _owners,
    uint256[] calldata _ids
  ) external view returns (uint256[] memory _balances) {
    if (_owners.length != _ids.length) {
      revert ERC1155ArrayLengthMismatch();
    }

    _balances = new uint256[](_owners.length);

    // Unchecked because the only math done is incrementing
    // the array index counter which cannot possibly overflow.
    unchecked {
      for (uint256 i = 0; i < _owners.length; ++i) {
        _balances[i] = _balanceOf[_owners[i]][_ids[i]];
      }
    }
  }

  /**
   *  @notice Returns the total circulating supply of NFTs.
   *  @return supply The total circulating supply of NFTs
   */
  function totalSupply(uint256 _id) public view virtual returns (uint256) {
    return _totalSupply[_id];
  }

  /**
   *  @notice Returns whether the contract implements an interface with the given interface ID.
   *  @param _interfaceId The interface ID of the interface to check for
   */
  function supportsInterface(
    bytes4 _interfaceId
  ) public view virtual returns (bool) {
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
    isApprovedForAll[msg.sender][_operator] = _approved;

    emit ApprovalForAll(msg.sender, _operator, _approved);
  }

  /**
   *  @notice Transfers ownership of an NFT from one address to another. If transfer is recipient is a smart contract,
   *          checks if recipient implements ERC721Receiver interface and calls the `onERC721Received` function.
   *  @param _from The address to transfer from
   *  @param _to The address to transfer to
   *  @param _id The token ID of the NFT
   *  @param _value Total number of NFTs with that id
   *  @param _data data
   */
  function safeTransferFrom(
    address _from,
    address _to,
    uint256 _id,
    uint256 _value,
    bytes calldata _data
  ) public virtual {
    require(
      msg.sender == _from || isApprovedForAll[_from][msg.sender],
      "NOT_AUTHORIZED"
    );

    _balanceOf[_from][_id] -= _value;
    _balanceOf[_to][_id] += _value;

    emit TransferSingle(msg.sender, _from, _to, _id, _value);

    if (
      _to.code.length == 0
        ? _to == address(0)
        : IERC1155Receiver(_to).onERC1155Received(
          msg.sender,
          _from,
          _id,
          _value,
          _data
        ) != IERC1155Receiver.onERC1155Received.selector
    ) {
      revert ERC1155UnsafeRecipient(_to);
    }
  }

  function safeBatchTransferFrom(
    address _from,
    address _to,
    uint256[] calldata _ids,
    uint256[] calldata _values,
    bytes calldata _data
  ) public virtual {
    if (_ids.length != _values.length) {
      revert ERC1155ArrayLengthMismatch();
    }

    if (msg.sender != _from && !isApprovedForAll[_from][msg.sender]) {
      revert ERC1155NotApprovedOrOwner(msg.sender);
    }

    // Storing these outside the loop saves ~15 gas per iteration.
    uint256 id;
    uint256 value;

    for (uint256 i = 0; i < _ids.length; ) {
      id = _ids[i];
      value = _values[i];

      _balanceOf[_from][id] -= value;
      _balanceOf[_to][id] += value;

      // An array can't have a total length
      // larger than the max uint256 value.
      unchecked {
        ++i;
      }
    }

    emit TransferBatch(msg.sender, _from, _to, _ids, _values);

    if (
      _to.code.length == 0
        ? _to == address(0)
        : IERC1155Receiver(_to).onERC1155BatchReceived(
          msg.sender,
          _from,
          _ids,
          _values,
          _data
        ) != IERC1155Receiver.onERC1155BatchReceived.selector
    ) {
      revert ERC1155UnsafeRecipient(_to);
    }
  }

  /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  function _mint(
    address _to,
    uint256 _id,
    uint256 _value,
    bytes memory _data
  ) internal virtual {
    _balanceOf[_to][_id] += _value;

    emit TransferSingle(msg.sender, address(0), _to, _id, _value);

    if (
      _to.code.length == 0
        ? _to == address(0)
        : IERC1155Receiver(_to).onERC1155Received(
          msg.sender,
          address(0),
          _id,
          _value,
          _data
        ) != IERC1155Receiver.onERC1155BatchReceived.selector
    ) {
      revert ERC1155UnsafeRecipient(_to);
    }
  }

  function _batchMint(
    address _to,
    uint256[] memory _ids,
    uint256[] memory _values,
    bytes memory _data
  ) internal virtual {
    uint256 idsLength = _ids.length; // Saves MLOADs.

    if (idsLength != _values.length) {
      revert ERC1155ArrayLengthMismatch();
    }

    for (uint256 i = 0; i < idsLength; ) {
      _balanceOf[_to][_ids[i]] += _values[i];

      // An array can't have a total length
      // larger than the max uint256 value.
      unchecked {
        ++i;
      }
    }

    emit TransferBatch(msg.sender, address(0), _to, _ids, _values);

    if (
      _to.code.length == 0
        ? _to == address(0)
        : IERC1155Receiver(_to).onERC1155BatchReceived(
          msg.sender,
          address(0),
          _ids,
          _values,
          _data
        ) != IERC1155Receiver.onERC1155BatchReceived.selector
    ) {
      revert ERC1155UnsafeRecipient(_to);
    }
  }

  function _burn(address _from, uint256 _id, uint256 _value) internal virtual {
    if (_from == address(0)) {
      revert ERC1155BurnFromZeroAddress();
    }

    uint256 balance = _balanceOf[_from][_id];

    if (balance < _value) {
      revert ERC1155NotBalance(_from, _id, _value);
    }

    unchecked {
      _balanceOf[_from][_id] -= _value;
    }

    emit TransferSingle(msg.sender, _from, address(0), _id, _value);
  }

  function _burnBatch(
    address _from,
    uint256[] memory _ids,
    uint256[] memory _values
  ) internal virtual {
    if (_from == address(0)) {
      revert ERC1155BurnFromZeroAddress();
    }

    uint256 idsLength = _ids.length; // Saves MLOADs.

    if (idsLength != _values.length) {
      revert ERC1155ArrayLengthMismatch();
    }

    for (uint256 i = 0; i < idsLength; ) {
      _balanceOf[_from][_ids[i]] -= _values[i];

      uint256 balance = _balanceOf[_from][_ids[i]];

      if (balance < _values[i]) {
        revert ERC1155NotBalance(_from, _ids[i], _values[i]);
      }

      unchecked {
        _balanceOf[_from][_ids[i]] -= _values[i];
        ++i;
      }
    }

    emit TransferBatch(msg.sender, _from, address(0), _ids, _values);
  }
}
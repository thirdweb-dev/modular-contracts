// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import { Initializable } from  "../extension/Initializable.sol";
import { IERC721 } from "../interface/erc721/IERC721.sol";
import { IERC721Metadata } from "../interface/erc721/IERC721Metadata.sol";

/**
 *  CHANGELOG:
 *      - Make contract initializable.
 *      - Replace _ownerOf with _tokenData.
 *      - Replace `require` statements with custom errors.
 *      - Remove require(owner != address(0)) statement from `balanceOf`.
 *      - Move events and errors to interface
 *      - Implement tokenURI
 */

/// @notice Modern, minimalist, and gas efficient ERC-721 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
contract ERC721 is Initializable, IERC721, IERC721Metadata {

    /*//////////////////////////////////////////////////////////////
                         METADATA STORAGE/LOGIC
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    function tokenURI(uint256 _id) public view virtual returns (string memory metadata) {
        return IERC721Metadata(_tokenData[_id].metadataSource).tokenURI(_id);
    }

    function metadataSourceOf(uint256 _id) public view virtual returns (address) {
        return _tokenData[_id].metadataSource;
    }

    /*//////////////////////////////////////////////////////////////
                      ERC721 BALANCE/OWNER STORAGE
    //////////////////////////////////////////////////////////////*/

    struct TokenData {
        address owner;
        address metadataSource;
    }

    mapping(uint256 => TokenData) private _tokenData;
    mapping(address => uint256) private _balanceOf;

    function ownerOf(uint256 _id) public view virtual returns (address owner) {
        if((owner = _tokenData[_id].owner) == address(0)) {
            revert ERC721NotMinted(_id);
        }
    }

    function balanceOf(address owner) public view virtual returns (uint256) {
        return _balanceOf[owner];
    }

    /*//////////////////////////////////////////////////////////////
                         ERC721 APPROVAL STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {}

    function __ERC721_init(string memory _name, string memory _symbol) internal onlyInitializing {
        name = _name;
        symbol = _symbol;
    }

    /*//////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address _spender, uint256 _id) public virtual {
        address owner = _tokenData[_id].owner;

        if(msg.sender != owner && !isApprovedForAll[owner][msg.sender]) {
            revert ERC721NotApproved(msg.sender, _id);
        }

        getApproved[_id] = _spender;

        emit Approval(owner, _spender, _id);
    }

    function setApprovalForAll(address _operator, bool _approved) public virtual {
        isApprovedForAll[msg.sender][_operator] = _approved;

        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

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

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id
    ) public virtual {
        transferFrom(_from, _to, _id);

        if(
            _to.code.length != 0 
                && ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _id, "") != ERC721TokenReceiver.onERC721Received.selector
        ) {
            revert ERC721UnsafeRecipient(_to);
        }
        
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        bytes calldata data
    ) public virtual {
        transferFrom(_from, _to, _id);

        if(
            _to.code.length != 0 
                && ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _id, data) != ERC721TokenReceiver.onERC721Received.selector
        ) {
            revert ERC721UnsafeRecipient(_to);
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 _interfaceId) public view virtual returns (bool) {
        return
            _interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            _interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            _interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address _to, uint256 _id) internal virtual {
        if(_to == address(0)) {
            revert ERC721InvalidRecipient();
        }

        if(_tokenData[_id].owner != address(0)) {
            revert ERC721AlreadyMinted(_id);
        }

        // Counter overflow is incredibly unrealistic.
        unchecked {
            _balanceOf[_to]++;
        }

        _tokenData[_id].owner = _to;

        emit Transfer(address(0), _to, _id);
    }

    function _mint(address _to, uint256 _id, address _metadataSource) internal virtual {
        if(_to == address(0)) {
            revert ERC721InvalidRecipient();
        }

        if(_tokenData[_id].owner != address(0)) {
            revert ERC721AlreadyMinted(_id);
        }

        // Counter overflow is incredibly unrealistic.
        unchecked {
            _balanceOf[_to]++;
        }

        _tokenData[_id] = TokenData(_to, _metadataSource);

        emit Transfer(address(0), _to, _id);
    }

    function _burn(uint256 _id) internal virtual {
        address owner = _tokenData[_id].owner;

        if(owner == address(0)) {
            revert ERC721NotMinted(_id);
        }

        // Ownership check above ensures no underflow.
        unchecked {
            _balanceOf[owner]--;
        }

        delete _tokenData[_id].owner;

        delete getApproved[_id];

        emit Transfer(owner, address(0), _id);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL SAFE MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    function _safeMint(address _to, uint256 _id) internal virtual {
        _mint(_to, _id);

        if(
            _to.code.length != 0 
                && ERC721TokenReceiver(_to).onERC721Received(msg.sender, address(0), _id, "") != ERC721TokenReceiver.onERC721Received.selector
        ) {
            revert ERC721UnsafeRecipient(_to);
        }
    }

    function _safeMint(
        address _to,
        uint256 _id,
        bytes memory _data
    ) internal virtual {
        _mint(_to, _id);

        if(
            _to.code.length != 0 
                && ERC721TokenReceiver(_to).onERC721Received(msg.sender, address(0), _id, _data) != ERC721TokenReceiver.onERC721Received.selector
        ) {
            revert ERC721UnsafeRecipient(_to);
        }
    }
}

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}
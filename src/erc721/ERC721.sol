// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import { Initializable } from  "../extension/Initializable.sol";

/**
 *  CHANGELOG:
 *      - Make contract initializable.
 *      - Replace _ownerOf with _tokenData.
 *      - Replace `require` statements with custom errors.
 *      - Remove require(owner != address(0)) statement from `balanceOf`.
 */

/// @notice Modern, minimalist, and gas efficient ERC-721 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
contract ERC721 is Initializable {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotMinted(uint256 tokenId);
    error AlreadyMinted(uint256 tokenId);
    error NotAuthorized(address operator, uint256 tokenId);
    error NotOwner(address caller, uint256 tokenId);
    error InvalidRecipient();
    error UnsafeRecipient(address recipient);

    /*//////////////////////////////////////////////////////////////
                         METADATA STORAGE/LOGIC
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    mapping(uint256 => string) internal _tokenURI;

    function tokenURI(uint256 id) public view virtual returns (string memory metadata) {

        // Prioritize metadata stored locally in the contract. Fall back to metadata returned from minter.

        metadata = _tokenURI[id];
        address minter = _tokenData[id].minter;
        
        if(bytes(metadata).length == 0 && minter != address(0)) {
            try IERC721Metadata(minter).tokenURI(id) returns (string memory uri) {
                return uri;
            } catch {}
        }
    }

    /*//////////////////////////////////////////////////////////////
                      ERC721 BALANCE/OWNER STORAGE
    //////////////////////////////////////////////////////////////*/

    struct TokenData {
        address owner;
        address minter;
    }

    mapping(uint256 => TokenData) internal _tokenData;
    mapping(address => uint256) internal _balanceOf;

    function ownerOf(uint256 id) public view virtual returns (address owner) {
        if((owner = _tokenData[id].owner) == address(0)) {
            revert NotMinted(id);
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

    function approve(address spender, uint256 id) public virtual {
        address owner = _tokenData[id].owner;

        if(msg.sender != owner && !isApprovedForAll[owner][msg.sender]) {
            revert NotAuthorized(msg.sender, id);
        }

        getApproved[id] = spender;

        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        if(from != _tokenData[id].owner) {
            revert NotOwner(from, id);
        }

        if(to == address(0)) {
            revert InvalidRecipient();
        }

        if(msg.sender != from && !isApprovedForAll[from][msg.sender] && msg.sender != getApproved[id]) {
            revert NotAuthorized(msg.sender, id);
        }

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        unchecked {
            _balanceOf[from]--;

            _balanceOf[to]++;
        }

        _tokenData[id].owner = to;

        delete getApproved[id];

        emit Transfer(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        transferFrom(from, to, id);

        if(
            to.code.length != 0 
                && ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") != ERC721TokenReceiver.onERC721Received.selector
        ) {
            revert UnsafeRecipient(to);
        }
        
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public virtual {
        transferFrom(from, to, id);

        if(
            to.code.length != 0 
                && ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data) != ERC721TokenReceiver.onERC721Received.selector
        ) {
            revert UnsafeRecipient(to);
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 id) internal virtual {
        if(to == address(0)) {
            revert InvalidRecipient();
        }

        if(_tokenData[id].owner != address(0)) {
            revert AlreadyMinted(id);
        }

        // Counter overflow is incredibly unrealistic.
        unchecked {
            _balanceOf[to]++;
        }

        _tokenData[id].owner = to;

        emit Transfer(address(0), to, id);
    }

    function _mint(address to, uint256 id, address _hook) internal virtual {
        if(to == address(0)) {
            revert InvalidRecipient();
        }

        if(_tokenData[id].owner != address(0)) {
            revert AlreadyMinted(id);
        }

        // Counter overflow is incredibly unrealistic.
        unchecked {
            _balanceOf[to]++;
        }

        _tokenData[id] = TokenData(to, _hook);

        emit Transfer(address(0), to, id);
    }

    function _burn(uint256 id) internal virtual {
        address owner = _tokenData[id].owner;

        if(owner == address(0)) {
            revert NotMinted(id);
        }

        // Ownership check above ensures no underflow.
        unchecked {
            _balanceOf[owner]--;
        }

        delete _tokenData[id].owner;

        delete getApproved[id];

        emit Transfer(owner, address(0), id);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL SAFE MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    function _safeMint(address to, uint256 id) internal virtual {
        _mint(to, id);

        if(
            to.code.length != 0 
                && ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, "") != ERC721TokenReceiver.onERC721Received.selector
        ) {
            revert UnsafeRecipient(to);
        }
    }

    function _safeMint(
        address to,
        uint256 id,
        bytes memory data
    ) internal virtual {
        _mint(to, id);

        if(
            to.code.length != 0 
                && ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, data) != ERC721TokenReceiver.onERC721Received.selector
        ) {
            revert UnsafeRecipient(to);
        }
    }
}

/// @notice A generic interface for a contract that returns token URI metadata for ERC721 tokens.
interface IERC721Metadata {
    function tokenURI(uint256 id) external view returns (string memory);
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
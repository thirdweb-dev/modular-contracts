// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Initializable} from "@solady/utils/Initializable.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";
import {Ownable} from "@solady/auth/Ownable.sol";

import {IERC7572} from "../../interface/eip/IERC7572.sol";
import {IERC1155Hook} from "../../interface/hook/IERC1155Hook.sol";
import {IERC1155HookInstaller} from "../../interface/hook/IERC1155HookInstaller.sol";
import {IInitCall} from "../../interface/common/IInitCall.sol";
import {ERC1155Initializable} from "./ERC1155Initializable.sol";
import {IHook, HookInstaller} from "../../hook/HookInstaller.sol";

contract ERC1155Core is
    Initializable,
    Multicallable,
    Ownable,
    ERC1155Initializable,
    HookInstaller,
    IInitCall,
    IERC1155HookInstaller,
    IERC7572
{
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on an attempt to mint tokens when either beforeMint hook is absent or unsuccessful.
    error ERC1155CoreMintingDisabled();

    /// @notice Emitted on a failed attempt to initialize the contract.
    error ERC1155CoreInitializationFailed();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing the before mint hook.
    uint256 public constant BEFORE_MINT_FLAG = 2**1;

    /// @notice Bits representing the before transfer hook.
    uint256 public constant BEFORE_TRANSFER_FLAG = 2**2;

    /// @notice Bits representing the before burn hook.
    uint256 public constant BEFORE_BURN_FLAG = 2**3;

    /// @notice Bits representing the before approve hook.
    uint256 public constant BEFORE_APPROVE_FLAG = 2**4;

    /// @notice Bits representing the token URI hook.
    uint256 public constant TOKEN_URI_FLAG = 2**5;

    /// @notice Bits representing the royalty hook.
    uint256 public constant ROYALTY_INFO_FLAG = 2**6;

    /// @notice Bits representing the before transfer hook.
    uint256 public constant BEFORE_BATCH_TRANSFER_FLAG = 2**7;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The contract URI of the contract.
    string private contractURI_;

    /*//////////////////////////////////////////////////////////////
                    CONSTRUCTOR + INITIALIZE
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    /**
     *  @notice Initializes the ERC-1155 Core contract.
     *  @param _hooks The hooks to install.
     *  @param _owner The owner of the contract.
     *  @param _name The name of the token collection.
     *  @param _symbol The symbol of the token collection.
     *  @param _contractURI Contract URI
     */
    function initialize(
        InitCall calldata _initCall,
        address[] memory _hooks,
        address _owner,
        string memory _name,
        string memory _symbol,
        string memory _contractURI
    ) external initializer {
        _setupContractURI(_contractURI);
        __ERC1155_init(_name, _symbol);
        _setOwner(_owner);

        uint256 len = _hooks.length;
        for (uint256 i = 0; i < len; i++) {
            _installHook(IHook(_hooks[i]));
        }

        if (_initCall.target != address(0)) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, bytes memory returndata) = _initCall.target.call{
                value: _initCall.value
            }(_initCall.data);
            if (!success) {
                if (returndata.length > 0) {
                    // solhint-disable-next-line no-inline-assembly
                    assembly {
                        revert(add(returndata, 32), mload(returndata))
                    }
                } else {
                    revert ERC1155CoreInitializationFailed();
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all of the contract's hooks and their implementations.
    function getAllHooks() external view returns (ERC1155Hooks memory hooks) {
        hooks = ERC1155Hooks({
            beforeMint: getHookImplementation(BEFORE_MINT_FLAG),
            beforeTransfer: getHookImplementation(BEFORE_TRANSFER_FLAG),
            beforeBatchTransfer: getHookImplementation(
                BEFORE_BATCH_TRANSFER_FLAG
            ),
            beforeBurn: getHookImplementation(BEFORE_BURN_FLAG),
            beforeApprove: getHookImplementation(BEFORE_APPROVE_FLAG),
            uri: getHookImplementation(TOKEN_URI_FLAG),
            royaltyInfo: getHookImplementation(ROYALTY_INFO_FLAG)
        });
    }

    /**
     *  @notice Returns the contract URI of the contract.
     *  @return uri The contract URI of the contract.
     */
    function contractURI() external view override returns (string memory) {
        return contractURI_;
    }

    /**
     *  @notice Returns the token metadata of an NFT.
     *  @dev Always returns metadata queried from the metadata source.
     *  @param _tokenId The token ID of the NFT.
     *  @return metadata The URI to fetch metadata from.
     */
    function uri(uint256 _tokenId) public view returns (string memory) {
        return _getTokenURI(_tokenId);
    }

    /**
     *  @notice Returns the royalty amount for a given NFT and sale price.
     *  @param _tokenId The token ID of the NFT
     *  @param _salePrice The sale price of the NFT
     *  @return recipient The royalty recipient address
     *  @return royaltyAmount The royalty amount to send to the recipient as part of a sale
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address, uint256)
    {
        return _getRoyaltyInfo(_tokenId, _salePrice);
    }

    /**
     *  @notice Returns whether the contract implements an interface with the given interface ID.
     *  @param _interfaceId The interface ID of the interface to check for
     */
    function supportsInterface(bytes4 _interfaceId)
        public
        pure
        override
        returns (bool)
    {
        return
            _interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            _interfaceId == 0xd9b67a26 || // ERC165 Interface ID for ERC1155
            _interfaceId == 0x0e89341c || // ERC165 Interface ID for ERC1155MetadataURI
            _interfaceId == 0x2a55205a; // ERC165 Interface ID for ERC-2981
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Sets the contract URI of the contract.
     *  @dev Only callable by contract admin.
     *  @param _uri The contract URI to set.
     */
    function setContractURI(string memory _uri) external onlyOwner {
        _setupContractURI(_uri);
    }

    /**
     *  @notice Burns given amount of tokens.
     *  @dev Calls the beforeBurn hook. Skips calling the hook if it doesn't exist.
     *  @param _from Owner of the tokens
     *  @param _tokenId The token ID of the NFTs to burn.
     *  @param _value The amount of tokens to burn.
     *  @param _encodedBeforeBurnArgs ABI encoded arguments to pass to the beforeBurn hook.
     */
    function burn(
        address _from,
        uint256 _tokenId,
        uint256 _value,
        bytes memory _encodedBeforeBurnArgs
    ) external {
        if (_from != msg.sender && isApprovedForAll(_from, msg.sender)) {
            revert ERC1155NotApprovedOrOwner(msg.sender);
        }

        _beforeBurn(_from, _tokenId, _value, _encodedBeforeBurnArgs);
        _burn(_from, _tokenId, _value);
    }

    /**
     *  @notice Mints tokens with a given tokenId. Calls the beforeMint hook.
     *  @dev Reverts if beforeMint hook is absent or unsuccessful.
     *  @param _to The address to mint the token to.
     *  @param _tokenId The tokenId to mint.
     *  @param _value The amount of tokens to mint.
     *  @param _encodedBeforeMintArgs ABI encoded arguments to pass to the beforeMint hook.
     */
    function mint(
        address _to,
        uint256 _tokenId,
        uint256 _value,
        bytes memory _encodedBeforeMintArgs
    ) external payable {
        (uint256 tokenIdToMint, uint256 quantityToMint) = _beforeMint(
            _to,
            _tokenId,
            _value,
            _encodedBeforeMintArgs
        );
        _mint(_to, tokenIdToMint, quantityToMint, "");
    }

    /**
     *  @notice Transfers ownership of an NFT from one address to another.
     *  @dev Overriden to call the beforeTransfer hook. Skips calling the hook if it doesn't exist.
     *  @param _from The address to transfer from
     *  @param _to The address to transfer to
     *  @param _tokenId The token ID of the NFT
     */
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 _value,
        bytes calldata _data
    ) public override {
        _beforeTransfer(_from, _to, _tokenId, _value);
        super.safeTransferFrom(_from, _to, _tokenId, _value, _data);
    }

    /**
     *  @notice Transfers ownership of an NFT from one address to another.
     *  @dev Overriden to call the beforeTransfer hook. Skips calling the hook if it doesn't exist.
     *  @param _from The address to transfer from
     *  @param _to The address to transfer to
     *  @param _tokenIds The token ID of the NFT
     */
    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _tokenIds,
        uint256[] calldata _values,
        bytes calldata _data
    ) public override {
        _beforeBatchTransfer(_from, _to, _tokenIds, _values);
        super.safeBatchTransferFrom(_from, _to, _tokenIds, _values, _data);
    }

    /**
     *  @notice Approves an address to transfer all NFTs. Reverts if caller is not owner or approved operator.
     *  @dev Overriden to call the beforeApprove hook. Skips calling the hook if it doesn't exist.
     *  @param _operator The address to approve
     *  @param _approved To grant or revoke approval
     */
    function setApprovalForAll(address _operator, bool _approved)
        public
        override
    {
        _beforeApprove(msg.sender, _operator, _approved);
        super.setApprovalForAll(_operator, _approved);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Sets contract URI
    function _setupContractURI(string memory _uri) internal {
        contractURI_ = _uri;
        emit ContractURIUpdated();
    }

    /// @dev Returns whether the given caller can update hooks.
    function _canUpdateHooks(address _caller)
        internal
        view
        override
        returns (bool)
    {
        return _caller == owner();
    }

    /// @dev Returns whether the caller can write to hooks.
    function _canWriteToHooks(address _caller)
        internal
        view
        override
        returns (bool)
    {
        return _caller == owner();
    }

    /// @dev Should return the max flag that represents a hook.
    function _maxHookFlag() internal pure override returns (uint256) {
        return ROYALTY_INFO_FLAG;
    }

    /*//////////////////////////////////////////////////////////////
                        HOOKS INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Calls the beforeMint hook.
    function _beforeMint(
        address _to,
        uint256 _tokenId,
        uint256 _value,
        bytes memory _data
    ) internal virtual returns (uint256 tokenIdToMint, uint256 quantityToMint) {
        address hook = getHookImplementation(BEFORE_MINT_FLAG);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) = hook.call{
                value: msg.value
            }(
                abi.encodeWithSelector(
                    IERC1155Hook.beforeMint.selector,
                    _to,
                    _tokenId,
                    _value,
                    _data
                )
            );
            if (!success) _revert(returndata);
            (tokenIdToMint, quantityToMint) = abi.decode(
                returndata,
                (uint256, uint256)
            );
        } else {
            revert ERC1155CoreMintingDisabled();
        }
    }

    /// @dev Calls the beforeTransfer hook, if installed.
    function _beforeTransfer(
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 _value
    ) internal virtual {
        address hook = getHookImplementation(BEFORE_TRANSFER_FLAG);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) = hook.call{
                value: msg.value
            }(
                abi.encodeWithSelector(
                    IERC1155Hook.beforeTransfer.selector,
                    _from,
                    _to,
                    _tokenId,
                    _value
                )
            );
            if (!success) _revert(returndata);
        }
    }

    /// @dev Calls the beforeTransfer hook, if installed.
    function _beforeBatchTransfer(
        address _from,
        address _to,
        uint256[] calldata _tokenIds,
        uint256[] calldata _values
    ) internal virtual {
        address hook = getHookImplementation(BEFORE_BATCH_TRANSFER_FLAG);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) = hook.call{
                value: msg.value
            }(
                abi.encodeWithSelector(
                    IERC1155Hook.beforeBatchTransfer.selector,
                    _from,
                    _to,
                    _tokenIds,
                    _values
                )
            );
            if (!success) _revert(returndata);
        }
    }

    /// @dev Calls the beforeBurn hook, if installed.
    function _beforeBurn(
        address _from,
        uint256 _tokenId,
        uint256 _value,
        bytes memory _encodedBeforeBurnArgs
    ) internal virtual {
        address hook = getHookImplementation(BEFORE_BURN_FLAG);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) = hook.call{
                value: msg.value
            }(
                abi.encodeWithSelector(
                    IERC1155Hook.beforeBurn.selector,
                    _from,
                    _tokenId,
                    _value,
                    _encodedBeforeBurnArgs
                )
            );
            if (!success) _revert(returndata);
        }
    }

    /// @dev Calls the beforeApprove hook, if installed.
    function _beforeApprove(
        address _from,
        address _to,
        bool _approved
    ) internal virtual {
        address hook = getHookImplementation(BEFORE_APPROVE_FLAG);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) = hook.call{
                value: msg.value
            }(
                abi.encodeWithSelector(
                    IERC1155Hook.beforeApprove.selector,
                    _from,
                    _to,
                    _approved
                )
            );
            if (!success) _revert(returndata);
        }
    }

    /// @dev Fetches token URI from the token metadata hook.
    function _getTokenURI(uint256 _tokenId)
        internal
        view
        virtual
        returns (string memory _uri)
    {
        address hook = getHookImplementation(TOKEN_URI_FLAG);

        if (hook != address(0)) {
            _uri = IERC1155Hook(hook).uri(_tokenId);
        }
    }

    /// @dev Fetches royalty info from the royalty hook.
    function _getRoyaltyInfo(uint256 _tokenId, uint256 _salePrice)
        internal
        view
        virtual
        returns (address receiver, uint256 royaltyAmount)
    {
        address hook = getHookImplementation(ROYALTY_INFO_FLAG);

        if (hook != address(0)) {
            (receiver, royaltyAmount) = IERC1155Hook(hook).royaltyInfo(
                _tokenId,
                _salePrice
            );
        }
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Ownable} from "@solady/auth/Ownable.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";
import {ERC1155} from "@solady/tokens/ERC1155.sol";

import {HookInstaller} from "../HookInstaller.sol";

import {IERC1155HookInstaller} from "../../interface/hook/IERC1155HookInstaller.sol";
import {IERC1155Hook} from "../../interface/hook/IERC1155Hook.sol";
import {IERC7572} from "../../interface/eip/IERC7572.sol";

contract ERC1155Core is ERC1155, HookInstaller, Ownable, Multicallable, IERC7572, IERC1155HookInstaller {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing the before mint hook.
    uint256 public constant BEFORE_MINT_FLAG = 2 ** 1;

    /// @notice Bits representing the before transfer hook.
    uint256 public constant BEFORE_TRANSFER_FLAG = 2 ** 2;

    /// @notice Bits representing the before burn hook.
    uint256 public constant BEFORE_BURN_FLAG = 2 ** 3;

    /// @notice Bits representing the before approve hook.
    uint256 public constant BEFORE_APPROVE_FLAG = 2 ** 4;

    /// @notice Bits representing the token URI hook.
    uint256 public constant TOKEN_URI_FLAG = 2 ** 5;

    /// @notice Bits representing the royalty hook.
    uint256 public constant ROYALTY_INFO_FLAG = 2 ** 6;

    /// @notice Bits representing the before transfer hook.
    uint256 public constant BEFORE_BATCH_TRANSFER_FLAG = 2 ** 7;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The name of the NFT collection.
    string private name_;

    /// @notice The symbol of the NFT collection.
    string private symbol_;

    /// @notice The contract metadata URI of the contract.
    string private contractURI_;

    /// @notice The total supply of a tokenId of the NFT collection.
    mapping(uint256 => uint256) private totalSupply_;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the on initialize call fails.
    error ERC1155CoreOnInitializeCallFailed();

    /// @notice Emitted when a hook initialization call fails.
    error ERC1155CoreHookInitializeCallFailed();

    /// @notice Emitted when a hook call fails.
    error ERC1155CoreHookCallFailed();

    /// @notice Emitted when insufficient value is sent in the constructor.
    error ERC1155CoreInsufficientValueInConstructor();

    /// @notice Emitted on an attempt to mint tokens when no beforeMint hook is installed.
    error ERC1155CoreMintDisabled();

    /**
     *  @notice Initializes the ERC1155 NFT collection.
     *
     *  @param _name The name of the NFT collection.
     *  @param _symbol The symbol of the NFT collection.
     *  @param _contractURI The contract URI of the NFT collection.
     *  @param _owner The owner of the contract.
     *  @param _onInitializeCall Any external call to make on contract initialization.
     *  @param _hooksToInstall Any hooks to install and initialize on contract initialization.
     */
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _contractURI,
        address _owner,
        OnInitializeParams memory _onInitializeCall,
        InstallHookParams[] memory _hooksToInstall
    ) payable {
        // Set contract metadata
        name_ = _name;
        symbol_ = _symbol;
        _setupContractURI(_contractURI);

        // Set contract owner
        _setOwner(_owner);

        // Track native token value sent to the constructor
        uint256 constructorValue = msg.value;

        // Initialize the core NFT collection
        if (_onInitializeCall.target != address(0)) {
            if (constructorValue < _onInitializeCall.value) revert ERC1155CoreInsufficientValueInConstructor();
            constructorValue -= _onInitializeCall.value;

            (bool successOnInitialize, bytes memory returndataOnInitialize) =
                _onInitializeCall.target.call{value: _onInitializeCall.value}(_onInitializeCall.data);

            if (!successOnInitialize) _revert(returndataOnInitialize, ERC1155CoreOnInitializeCallFailed.selector);
        }

        // Install and initialize hooks
        bool successHookInstall;
        bytes memory returndataHookInstall;

        for (uint256 i = 0; i < _hooksToInstall.length; i++) {
            if (constructorValue < _hooksToInstall[i].initCallValue) revert ERC1155CoreInsufficientValueInConstructor();
            constructorValue -= _onInitializeCall.value;

            if (address(_hooksToInstall[i].hook) == address(0)) {
                revert HookInstallerInvalidHook();
            }

            _installHook(_hooksToInstall[i].hook);

            if (_hooksToInstall[i].initCalldata.length > 0) {
                (successHookInstall, returndataHookInstall) = address(_hooksToInstall[i].hook).call{
                    value: _hooksToInstall[i].initCallValue
                }(_hooksToInstall[i].initCalldata);

                if (!successHookInstall) _revert(returndataHookInstall, ERC1155CoreHookInitializeCallFailed.selector);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the name of the NFT Collection.
    function name() public view returns (string memory) {
        return name_;
    }

    /// @notice Returns the symbol of the NFT Collection.
    function symbol() public view returns (string memory) {
        return symbol_;
    }

    /**
     *  @notice Returns the contract URI of the contract.
     *  @return uri The contract URI of the contract.
     */
    function contractURI() external view override returns (string memory) {
        return contractURI_;
    }

    /**
     *  @notice Returns the total supply of a tokenId of the NFT collection.
     *  @param _tokenId The token ID of the NFT.
     */
    function totalSupply(uint256 _tokenId) public view virtual returns (uint256) {
        return totalSupply_[_tokenId];
    }

    /**
     *  @notice Returns the token metadata of an NFT.
     *  @dev Always returns metadata queried from the metadata source.
     *  @param _tokenId The token ID of the NFT.
     *  @return metadata The URI to fetch metadata from.
     */
    function uri(uint256 _tokenId) public view override returns (string memory) {
        return _getTokenURI(_tokenId);
    }

    /**
     *  @notice Returns the royalty amount for a given NFT and sale price.
     *  @param _tokenId The token ID of the NFT
     *  @param _salePrice The sale price of the NFT
     *  @return recipient The royalty recipient address
     *  @return royaltyAmount The royalty amount to send to the recipient as part of a sale
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view returns (address, uint256) {
        return _getRoyaltyInfo(_tokenId, _salePrice);
    }

    /**
     *  @notice Returns whether the contract implements an interface with the given interface ID.
     *  @param _interfaceId The interface ID of the interface to check for
     */
    function supportsInterface(bytes4 _interfaceId) public pure override returns (bool) {
        return _interfaceId == 0x01ffc9a7 // ERC165 Interface ID for ERC165
            || _interfaceId == 0xd9b67a26 // ERC165 Interface ID for ERC1155
            || _interfaceId == 0x0e89341c // ERC165 Interface ID for ERC1155MetadataURI
            || _interfaceId == 0x2a55205a; // ERC165 Interface ID for ERC-2981
    }

    /// @notice Returns all of the contract's hooks and their implementations.
    function getAllHooks() external view returns (ERC1155Hooks memory hooks) {
        hooks = ERC1155Hooks({
            beforeMint: getHookImplementation(BEFORE_MINT_FLAG),
            beforeTransfer: getHookImplementation(BEFORE_TRANSFER_FLAG),
            beforeBatchTransfer: getHookImplementation(BEFORE_BATCH_TRANSFER_FLAG),
            beforeBurn: getHookImplementation(BEFORE_BURN_FLAG),
            beforeApprove: getHookImplementation(BEFORE_APPROVE_FLAG),
            uri: getHookImplementation(TOKEN_URI_FLAG),
            royaltyInfo: getHookImplementation(ROYALTY_INFO_FLAG)
        });
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
     *  @notice Mints tokens with a given tokenId. Calls the beforeMint hook.
     *  @dev Reverts if beforeMint hook is absent or unsuccessful.
     *  @param _to The address to mint the token to.
     *  @param _tokenId The tokenId to mint.
     *  @param _value The amount of tokens to mint.
     *  @param _encodedBeforeMintArgs ABI encoded arguments to pass to the beforeMint hook.
     */
    function mint(address _to, uint256 _tokenId, uint256 _value, bytes memory _encodedBeforeMintArgs)
        external
        payable
    {
        (uint256 tokenIdToMint, uint256 quantityToMint) = _beforeMint(_to, _tokenId, _value, _encodedBeforeMintArgs);
        _mint(_to, tokenIdToMint, quantityToMint, "");
        totalSupply_[tokenIdToMint] += quantityToMint;
    }

    /**
     *  @notice Burns given amount of tokens.
     *  @dev Calls the beforeBurn hook. Skips calling the hook if it doesn't exist.
     *  @param _from Owner of the tokens
     *  @param _tokenId The token ID of the NFTs to burn.
     *  @param _value The amount of tokens to burn.
     *  @param _encodedBeforeBurnArgs ABI encoded arguments to pass to the beforeBurn hook.
     */
    function burn(address _from, uint256 _tokenId, uint256 _value, bytes memory _encodedBeforeBurnArgs) external {
        _beforeBurn(_from, _tokenId, _value, _encodedBeforeBurnArgs);
        _burn(msg.sender, _from, _tokenId, _value);
        totalSupply_[_tokenId] -= _value;
    }

    /**
     *  @notice Transfers ownership of an NFT from one address to another.
     *  @dev Overriden to call the beforeTransfer hook. Skips calling the hook if it doesn't exist.
     *  @param _from The address to transfer from
     *  @param _to The address to transfer to
     *  @param _tokenId The token ID of the NFT
     */
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, uint256 _value, bytes calldata _data)
        public
        override
    {
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
    function setApprovalForAll(address _operator, bool _approved) public override {
        _beforeApprove(msg.sender, _operator, _approved);
        super.setApprovalForAll(_operator, _approved);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns whether the given caller can update hooks.
    function _canUpdateHooks(address _caller) internal view override returns (bool) {
        return _caller == owner();
    }

    /// @dev Returns whether the caller can write to hooks.
    function _canWriteToHooks(address _caller) internal view override returns (bool) {
        return _caller == owner();
    }

    /// @dev Should return the max flag that represents a hook.
    function _maxHookFlag() internal pure override returns (uint8) {
        return uint8(BEFORE_BATCH_TRANSFER_FLAG);
    }

    /// @dev Sets contract URI
    function _setupContractURI(string memory _uri) internal {
        contractURI_ = _uri;
        emit ContractURIUpdated();
    }

    /*//////////////////////////////////////////////////////////////
                        HOOKS INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Calls the beforeMint hook.
    function _beforeMint(address _to, uint256 _tokenId, uint256 _value, bytes memory _data)
        internal
        virtual
        returns (uint256 tokenIdToMint, uint256 quantityToMint)
    {
        address hook = getHookImplementation(BEFORE_MINT_FLAG);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) = hook.call{value: msg.value}(
                abi.encodeWithSelector(IERC1155Hook.beforeMint.selector, _to, _tokenId, _value, _data)
            );
            if (!success) _revert(returndata, ERC1155CoreHookCallFailed.selector);
            (tokenIdToMint, quantityToMint) = abi.decode(returndata, (uint256, uint256));
        } else {
            revert ERC1155CoreMintDisabled();
        }
    }

    /// @dev Calls the beforeTransfer hook, if installed.
    function _beforeTransfer(address _from, address _to, uint256 _tokenId, uint256 _value) internal virtual {
        address hook = getHookImplementation(BEFORE_TRANSFER_FLAG);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) = hook.call{value: msg.value}(
                abi.encodeWithSelector(IERC1155Hook.beforeTransfer.selector, _from, _to, _tokenId, _value)
            );
            if (!success) _revert(returndata, ERC1155CoreHookCallFailed.selector);
        }
    }

    /// @dev Calls the beforeTransfer hook, if installed.
    function _beforeBatchTransfer(address _from, address _to, uint256[] calldata _tokenIds, uint256[] calldata _values)
        internal
        virtual
    {
        address hook = getHookImplementation(BEFORE_BATCH_TRANSFER_FLAG);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) = hook.call{value: msg.value}(
                abi.encodeWithSelector(IERC1155Hook.beforeBatchTransfer.selector, _from, _to, _tokenIds, _values)
            );
            if (!success) _revert(returndata, ERC1155CoreHookCallFailed.selector);
        }
    }

    /// @dev Calls the beforeBurn hook, if installed.
    function _beforeBurn(address _from, uint256 _tokenId, uint256 _value, bytes memory _encodedBeforeBurnArgs)
        internal
        virtual
    {
        address hook = getHookImplementation(BEFORE_BURN_FLAG);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) = hook.call{value: msg.value}(
                abi.encodeWithSelector(
                    IERC1155Hook.beforeBurn.selector, _from, _tokenId, _value, _encodedBeforeBurnArgs
                )
            );
            if (!success) _revert(returndata, ERC1155CoreHookCallFailed.selector);
        }
    }

    /// @dev Calls the beforeApprove hook, if installed.
    function _beforeApprove(address _from, address _to, bool _approved) internal virtual {
        address hook = getHookImplementation(BEFORE_APPROVE_FLAG);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) = hook.call{value: msg.value}(
                abi.encodeWithSelector(IERC1155Hook.beforeApprove.selector, _from, _to, _approved)
            );
            if (!success) _revert(returndata, ERC1155CoreHookCallFailed.selector);
        }
    }

    /// @dev Fetches token URI from the token metadata hook.
    function _getTokenURI(uint256 _tokenId) internal view virtual returns (string memory _uri) {
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
            (receiver, royaltyAmount) = IERC1155Hook(hook).royaltyInfo(_tokenId, _salePrice);
        }
    }
}

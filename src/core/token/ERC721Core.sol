// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Ownable} from "@solady/auth/Ownable.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";
import {ERC721} from "@solady/tokens/ERC721.sol";

import {HookInstaller} from "../HookInstaller.sol";

import {IERC721HookInstaller} from "../../interface/hook/IERC721HookInstaller.sol";
import {IERC721Hook} from "../../interface/hook/IERC721Hook.sol";
import {IERC7572} from "../../interface/eip/IERC7572.sol";

contract ERC721Core is ERC721, HookInstaller, Ownable, Multicallable, IERC7572, IERC721HookInstaller {
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

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The name of the NFT collection.
    string private name_;

    /// @notice The symbol of the NFT collection.
    string private symbol_;

    /// @notice The contract metadata URI of the contract.
    string private contractURI_;

    /// @notice The total supply of the NFT collection.
    uint256 private totalSupply_;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the on initialize call fails.
    error ERC721CoreOnInitializeCallFailed();

    /// @notice Emitted when a hook initialization call fails.
    error ERC721CoreHookInitializeCallFailed();

    /// @notice Emitted when a hook call fails.
    error ERC721CoreHookCallFailed();

    /// @notice Emitted when insufficient value is sent in the constructor.
    error ERC721CoreInsufficientValueInConstructor();

    /// @notice Emitted on an attempt to mint tokens when no beforeMint hook is installed.
    error ERC721CoreMintDisabled();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Initializes the ERC721 NFT collection.
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
            if (constructorValue < _onInitializeCall.value) revert ERC721CoreInsufficientValueInConstructor();
            constructorValue -= _onInitializeCall.value;

            (bool successOnInitialize, bytes memory returndataOnInitialize) =
                _onInitializeCall.target.call{value: _onInitializeCall.value}(_onInitializeCall.data);

            if (!successOnInitialize) _revert(returndataOnInitialize, ERC721CoreOnInitializeCallFailed.selector);
        }

        // Install and initialize hooks
        bool successHookInstall;
        bytes memory returndataHookInstall;

        for (uint256 i = 0; i < _hooksToInstall.length; i++) {
            if (constructorValue < _hooksToInstall[i].initCallValue) revert ERC721CoreInsufficientValueInConstructor();
            constructorValue -= _onInitializeCall.value;

            if (address(_hooksToInstall[i].hook) == address(0)) {
                revert HookInstallerInvalidHook();
            }

            _installHook(_hooksToInstall[i].hook);

            if (_hooksToInstall[i].initCalldata.length > 0) {
                (successHookInstall, returndataHookInstall) = address(_hooksToInstall[i].hook).call{
                    value: _hooksToInstall[i].initCallValue
                }(_hooksToInstall[i].initCalldata);

                if (!successHookInstall) _revert(returndataHookInstall, ERC721CoreHookInitializeCallFailed.selector);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the name of the NFT Collection.
    function name() public view override returns (string memory) {
        return name_;
    }

    /// @notice Returns the symbol of the NFT Collection.
    function symbol() public view override returns (string memory) {
        return symbol_;
    }

    /**
     *  @notice Returns the contract URI of the contract.
     *  @return uri The contract URI of the contract.
     */
    function contractURI() external view override returns (string memory) {
        return contractURI_;
    }

    /// @notice Returns the total supply of the NFT collection.
    function totalSupply() public view virtual returns (uint256) {
        return totalSupply_;
    }

    /**
     *  @notice Returns the token metadata of an NFT.
     *  @dev Always returns metadata queried from the metadata source.
     *  @param _id The token ID of the NFT.
     *  @return metadata The URI to fetch metadata from.
     */
    function tokenURI(uint256 _id) public view override returns (string memory) {
        return _getTokenURI(_id);
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
            || _interfaceId == 0x80ac58cd // ERC165 Interface ID for ERC721
            || _interfaceId == 0x5b5e139f // ERC165 Interface ID for ERC721Metadata
            || _interfaceId == 0x2a55205a; // ERC165 Interface ID for ERC-2981
    }

    /// @notice Returns all of the contract's hooks and their implementations.
    function getAllHooks() external view returns (ERC721Hooks memory hooks) {
        hooks = ERC721Hooks({
            beforeMint: getHookImplementation(BEFORE_MINT_FLAG),
            beforeTransfer: getHookImplementation(BEFORE_TRANSFER_FLAG),
            beforeBurn: getHookImplementation(BEFORE_BURN_FLAG),
            beforeApprove: getHookImplementation(BEFORE_APPROVE_FLAG),
            tokenURI: getHookImplementation(TOKEN_URI_FLAG),
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
     *  @notice Mints a token. Calls the beforeMint hook.
     *  @dev Reverts if beforeMint hook is absent or unsuccessful.
     *  @param _to The address to mint the token to.
     *  @param _quantity The quantity of tokens to mint.
     *  @param _encodedBeforeMintArgs ABI encoded arguments to pass to the beforeMint hook.
     */
    function mint(address _to, uint256 _quantity, bytes memory _encodedBeforeMintArgs) external payable {
        (uint256 startTokenId, uint256 quantityToMint) = _beforeMint(_to, _quantity, _encodedBeforeMintArgs);
        for (uint256 i = 0; i < quantityToMint; i++) {
            _mint(_to, startTokenId + i);
        }
        totalSupply_ += quantityToMint;
    }

    /**
     *  @notice Burns an NFT.
     *  @dev Calls the beforeBurn hook. Skips calling the hook if it doesn't exist.
     *  @param _tokenId The token ID of the NFT to burn.
     *  @param _encodedBeforeBurnArgs ABI encoded arguments to pass to the beforeBurn hook.
     */
    function burn(uint256 _tokenId, bytes memory _encodedBeforeBurnArgs) external {
        _beforeBurn(ownerOf(_tokenId), _tokenId, _encodedBeforeBurnArgs);
        _burn(msg.sender, _tokenId);
        totalSupply_--;
    }

    /**
     *  @notice Transfers ownership of an NFT from one address to another.
     *  @dev Overriden to call the beforeTransfer hook. Skips calling the hook if it doesn't exist.
     *  @param _from The address to transfer from
     *  @param _to The address to transfer to
     *  @param _id The token ID of the NFT
     */
    function transferFrom(address _from, address _to, uint256 _id) public payable override {
        _beforeTransfer(_from, _to, _id);
        super.transferFrom(_from, _to, _id);
    }

    /**
     *  @notice Approves an address to transfer a specific NFT. Reverts if caller is not owner or approved operator.
     *  @dev Overriden to call the beforeApprove hook. Skips calling the hook if it doesn't exist.
     *  @param _spender The address to approve
     *  @param _id The token ID of the NFT
     */
    function approve(address _spender, uint256 _id) public payable override {
        _beforeApprove(msg.sender, _spender, _id, true);
        super.approve(_spender, _id);
    }

    /**
     *  @notice Approves or revokes approval from an operator to transfer or issue approval for all of the caller's NFTs.
     *  @param _operator The address to approve or revoke approval from
     *  @param _approved Whether the operator is approved
     */
    function setApprovalForAll(address _operator, bool _approved) public override {
        _beforeApprove(msg.sender, _operator, type(uint256).max, _approved);
        super.setApprovalForAll(_operator, _approved);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns whether the caller can update hooks.
    function _canUpdateHooks(address _caller) internal view override returns (bool) {
        return _caller == owner();
    }

    /// @dev Returns whether the caller can write to hooks.
    function _canWriteToHooks(address _caller) internal view override returns (bool) {
        return _caller == owner();
    }

    /// @dev Should return the max flag that represents a hook.
    function _maxHookFlag() internal pure override returns (uint256) {
        return ROYALTY_INFO_FLAG;
    }

    /// @dev Sets contract URI
    function _setupContractURI(string memory _contractURI) internal {
        contractURI_ = _contractURI;
        emit ContractURIUpdated();
    }

    /// @dev Reverts with the given return data / error message.
    function _revert(bytes memory _returndata, bytes4 _errorSignature) internal pure {
        // Look for revert reason and bubble it up if present
        if (_returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(_returndata)
                revert(add(32, _returndata), returndata_size)
            }
        } else {
            assembly {
                mstore(0x00, _errorSignature)
                revert(0x1c, 0x04)
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        HOOKS INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Calls the beforeMint hook.
    function _beforeMint(address _to, uint256 _quantity, bytes memory _data)
        internal
        virtual
        returns (uint256 tokenIdToMint, uint256 quantityToMint)
    {
        address hook = getHookImplementation(BEFORE_MINT_FLAG);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) = hook.call{value: msg.value}(
                abi.encodeWithSelector(IERC721Hook.beforeMint.selector, _to, _quantity, _data)
            );
            if (!success) _revert(returndata, ERC721CoreHookCallFailed.selector);
            (tokenIdToMint, quantityToMint) = abi.decode(returndata, (uint256, uint256));
        } else {
            revert ERC721CoreMintDisabled();
        }
    }

    /// @dev Calls the beforeTransfer hook, if installed.
    function _beforeTransfer(address _from, address _to, uint256 _tokenId) internal virtual {
        address hook = getHookImplementation(BEFORE_TRANSFER_FLAG);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) = hook.call{value: msg.value}(
                abi.encodeWithSelector(IERC721Hook.beforeTransfer.selector, _from, _to, _tokenId)
            );
            if (!success) _revert(returndata, ERC721CoreHookCallFailed.selector);
        }
    }

    /// @dev Calls the beforeBurn hook, if installed.
    function _beforeBurn(address _from, uint256 _tokenId, bytes memory _encodedBeforeBurnArgs) internal virtual {
        address hook = getHookImplementation(BEFORE_BURN_FLAG);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) = hook.call{value: msg.value}(
                abi.encodeWithSelector(IERC721Hook.beforeBurn.selector, _from, _tokenId, _encodedBeforeBurnArgs)
            );
            if (!success) _revert(returndata, ERC721CoreHookCallFailed.selector);
        }
    }

    /// @dev Calls the beforeApprove hook, if installed.
    function _beforeApprove(address _from, address _to, uint256 _tokenId, bool _approve) internal virtual {
        address hook = getHookImplementation(BEFORE_APPROVE_FLAG);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) = hook.call{value: msg.value}(
                abi.encodeWithSelector(IERC721Hook.beforeApprove.selector, _from, _to, _tokenId, _approve)
            );
            if (!success) _revert(returndata, ERC721CoreHookCallFailed.selector);
        }
    }

    /// @dev Fetches token URI from the token metadata hook.
    function _getTokenURI(uint256 _tokenId) internal view virtual returns (string memory uri) {
        address hook = getHookImplementation(TOKEN_URI_FLAG);

        if (hook != address(0)) {
            uri = IERC721Hook(hook).tokenURI(_tokenId);
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
            (receiver, royaltyAmount) = IERC721Hook(hook).royaltyInfo(_tokenId, _salePrice);
        }
    }
}

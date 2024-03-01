// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import { Initializable } from "@solady/utils/Initializable.sol";
import { Multicallable } from "@solady/utils/Multicallable.sol";

import { IERC7572 } from "../../interface/eip/IERC7572.sol";
import { IERC721CoreCustomErrors } from "../../interface/errors/IERC721CoreCustomErrors.sol";
import { IERC721Hook } from "../../interface/hook/IERC721Hook.sol";
import { IERC721HookInstaller } from "../../interface/hook/IERC721HookInstaller.sol";
import { IInitCall } from "../../interface/common/IInitCall.sol";
import { ERC721Initializable } from "./ERC721Initializable.sol";
import { IHook, HookInstaller } from "../../hook/HookInstaller.sol";
import { Permission } from "../../common/Permission.sol";

import { ERC721CoreStorage } from "../../storage/core/ERC721CoreStorage.sol";

contract ERC721Core is
    Initializable,
    Multicallable,
    ERC721Initializable,
    HookInstaller,
    Permission,
    IInitCall,
    IERC721HookInstaller,
    IERC721CoreCustomErrors,
    IERC7572
{
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

    /*//////////////////////////////////////////////////////////////
                    CONSTRUCTOR + INITIALIZE
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    /**
     *  @notice Initializes the ERC-721 Core contract.
     *  @param _hooks The hooks to install.
     *  @param _defaultAdmin The default admin for the contract.
     *  @param _name The name of the token collection.
     *  @param _symbol The symbol of the token collection.
     */
    function initialize(
        InitCall calldata _initCall,
        address[] calldata _hooks,
        address _defaultAdmin,
        string memory _name,
        string memory _symbol,
        string memory _contractURI
    ) external initializer {
        _setupContractURI(_contractURI);
        __ERC721_init(_name, _symbol);
        _setupRole(_defaultAdmin, ADMIN_ROLE_BITS);

        uint256 len = _hooks.length;
        for (uint256 i = 0; i < len; i++) {
            _installHook(IHook(_hooks[i]));
        }

        if (_initCall.target != address(0)) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, bytes memory returnData) = _initCall.target.call{ value: _initCall.value }(_initCall.data);
            if (!success) {
                if (returnData.length > 0) {
                    // solhint-disable-next-line no-inline-assembly
                    assembly {
                        revert(add(returnData, 32), mload(returnData))
                    }
                } else {
                    revert ERC721CoreInitializationFailed();
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

    /**
     *  @notice Returns the contract URI of the contract.
     *  @return uri The contract URI of the contract.
     */
    function contractURI() external view override returns (string memory) {
        return ERC721CoreStorage.data().contractURI;
    }

    /**
     *  @notice Returns the token metadata of an NFT.
     *  @dev Always returns metadata queried from the metadata source.
     *  @param _id The token ID of the NFT.
     *  @return metadata The URI to fetch metadata from.
     */
    function tokenURI(uint256 _id) public view returns (string memory) {
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
    function supportsInterface(bytes4 _interfaceId) public view override returns (bool) {
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
     *  @notice Sets the contract URI of the contract.
     *  @dev Only callable by contract admin.
     *  @param _uri The contract URI to set.
     */
    function setContractURI(string memory _uri) external onlyAuthorized(ADMIN_ROLE_BITS) {
        _setupContractURI(_uri);
    }

    /**
     *  @notice Burns an NFT.
     *  @dev Calls the beforeBurn hook. Skips calling the hook if it doesn't exist.
     *  @param _tokenId The token ID of the NFT to burn.
     *  @param _encodedBeforeBurnArgs ABI encoded arguments to pass to the beforeBurn hook.
     */
    function burn(uint256 _tokenId, bytes memory _encodedBeforeBurnArgs) external {
        address owner = ownerOf(_tokenId);
        if (owner != msg.sender) {
            revert ERC721NotOwner(msg.sender, _tokenId);
        }

        _beforeBurn(owner, _tokenId, _encodedBeforeBurnArgs);
        _burn(_tokenId);
    }

    /**
     *  @notice Mints a token. Calls the beforeMint hook.
     *  @dev Reverts if beforeMint hook is absent or unsuccessful.
     *  @param _to The address to mint the token to.
     *  @param _quantity The quantity of tokens to mint.
     *  @param _encodedBeforeMintArgs ABI encoded arguments to pass to the beforeMint hook.
     */
    function mint(
        address _to,
        uint256 _quantity,
        bytes memory _encodedBeforeMintArgs
    ) external payable {
        (uint256 startTokenId, uint256 quantityToMint) = _beforeMint(_to, _quantity, _encodedBeforeMintArgs);
        _mint(_to, startTokenId, quantityToMint);
    }

    /**
     *  @notice Transfers ownership of an NFT from one address to another.
     *  @dev Overriden to call the beforeTransfer hook. Skips calling the hook if it doesn't exist.
     *  @param _from The address to transfer from
     *  @param _to The address to transfer to
     *  @param _id The token ID of the NFT
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _id
    ) public override {
        _beforeTransfer(_from, _to, _id);
        super.transferFrom(_from, _to, _id);
    }

    /**
     *  @notice Approves an address to transfer a specific NFT. Reverts if caller is not owner or approved operator.
     *  @dev Overriden to call the beforeApprove hook. Skips calling the hook if it doesn't exist.
     *  @param _spender The address to approve
     *  @param _id The token ID of the NFT
     */
    function approve(address _spender, uint256 _id) public override {
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

    /// @dev Sets contract URI
    function _setupContractURI(string memory _uri) internal {
        ERC721CoreStorage.data().contractURI = _uri;
        emit ContractURIUpdated();
    }

    /// @dev Returns whether the given caller can update hooks.
    function _canUpdateHooks(address _caller) internal view override returns (bool) {
        return hasRole(_caller, ADMIN_ROLE_BITS);
    }

    /// @dev Returns whether the caller can write to hooks.
    function _canWriteToHooks(address _caller) internal view override returns (bool) {
        return hasRole(_caller, ADMIN_ROLE_BITS);
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
        uint256 _quantity,
        bytes memory _data
    ) internal virtual returns (uint256 tokenIdToMint, uint256 quantityToMint) {
        address hook = getHookImplementation(BEFORE_MINT_FLAG);

        if (hook != address(0)) {
            (tokenIdToMint, quantityToMint) = IERC721Hook(hook).beforeMint{ value: msg.value }(_to, _quantity, _data);
        } else {
            revert ERC721CoreMintingDisabled();
        }
    }

    /// @dev Calls the beforeTransfer hook, if installed.
    function _beforeTransfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) internal virtual {
        address hook = getHookImplementation(BEFORE_TRANSFER_FLAG);

        if (hook != address(0)) {
            IERC721Hook(hook).beforeTransfer(_from, _to, _tokenId);
        }
    }

    /// @dev Calls the beforeBurn hook, if installed.
    function _beforeBurn(
        address _from,
        uint256 _tokenId,
        bytes memory _encodedBeforeBurnArgs
    ) internal virtual {
        address hook = getHookImplementation(BEFORE_BURN_FLAG);

        if (hook != address(0)) {
            IERC721Hook(hook).beforeBurn(_from, _tokenId, _encodedBeforeBurnArgs);
        }
    }

    /// @dev Calls the beforeApprove hook, if installed.
    function _beforeApprove(
        address _from,
        address _to,
        uint256 _tokenId,
        bool _approve
    ) internal virtual {
        address hook = getHookImplementation(BEFORE_APPROVE_FLAG);

        if (hook != address(0)) {
            IERC721Hook(hook).beforeApprove(_from, _to, _tokenId, _approve);
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

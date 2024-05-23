// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Initializable} from "@solady/utils/Initializable.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";
import {ERC1155} from "@solady/tokens/ERC1155.sol";

import {ModularCoreUpgradeable} from "../../ModularCoreUpgradeable.sol";

import {BeforeMintCallbackERC1155} from "../../callback/BeforeMintCallbackERC1155.sol";
import {BeforeTransferCallbackERC1155} from "../../callback/BeforeTransferCallbackERC1155.sol";
import {BeforeBatchTransferCallbackERC1155} from "../../callback/BeforeBatchTransferCallbackERC1155.sol";
import {BeforeBurnCallbackERC1155} from "../../callback/BeforeBurnCallbackERC1155.sol";
import {BeforeApproveForAllCallback} from "../../callback/BeforeApproveForAllCallback.sol";
import {OnTokenURICallback} from "../../callback/OnTokenURICallback.sol";

contract ERC1155CoreInitializable is ERC1155, ModularCoreUpgradeable, Multicallable, Initializable {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The name of the NFT collection.
    string private _name;

    /// @notice The symbol of the NFT collection.
    string private _symbol;

    /// @notice The contract metadata URI of the contract.
    string private _contractURI;

    /// @notice The total supply of a tokenId of the NFT collection.
    mapping(uint256 => uint256) private _totalSupply;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the contract URI is updated.
    event ContractURIUpdated();

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR & INITIALIZER
    //////////////////////////////////////////////////////////////*/

    constructor(address _erc1967Factory) ModularCoreUpgradeable(_erc1967Factory) {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        string memory contractURI,
        address owner,
        address[] memory extensions,
        bytes[] memory extensionInstallData
    ) external payable initializer {
        // Set contract metadata
        _name = name;
        _symbol = symbol;
        _setupContractURI(contractURI);
        _initializeOwner(owner);

        // Install and initialize hooks
        require(extensions.length == extensions.length);
        for (uint256 i = 0; i < extensions.length; i++) {
            _installExtension(extensions[i], extensionInstallData[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the name of the NFT Collection.
    function name() public view returns (string memory) {
        return _name;
    }

    /// @notice Returns the symbol of the NFT Collection.
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     *  @notice Returns the contract URI of the contract.
     *  @return uri The contract URI of the contract.
     */
    function contractURI() external view returns (string memory) {
        return _contractURI;
    }

    /**
     *  @notice Returns the total supply of a tokenId of the NFT collection.
     *  @param tokenId The token ID of the NFT.
     */
    function totalSupply(uint256 tokenId) public view virtual returns (uint256) {
        return _totalSupply[tokenId];
    }

    /**
     *  @notice Returns the token metadata of an NFT.
     *  @dev Always returns metadata queried from the metadata source.
     *  @param tokenId The token ID of the NFT.
     *  @return metadata The URI to fetch metadata from.
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        return _getTokenURI(tokenId);
    }

    /**
     *  @notice Returns whether the contract implements an interface with the given interface ID.
     *  @param interfaceId The interface ID of the interface to check for
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, ModularCoreUpgradeable)
        returns (bool)
    {
        return interfaceId == 0x01ffc9a7 // ERC165 Interface ID for ERC165
            || interfaceId == 0xd9b67a26 // ERC165 Interface ID for ERC1155
            || interfaceId == 0x0e89341c // ERC165 Interface ID for ERC1155MetadataURI
            || interfaceId == 0x2a55205a // ERC165 Interface ID for ERC-2981
            || super.supportsInterface(interfaceId); // right-most ModularCore
    }

    function getSupportedCallbackFunctions()
        public
        pure
        override
        returns (SupportedCallbackFunction[] memory supportedCallbackFunctions)
    {
        supportedCallbackFunctions = new SupportedCallbackFunction[](6);
        supportedCallbackFunctions[0] = SupportedCallbackFunction({
            selector: BeforeMintCallbackERC1155.beforeMintERC1155.selector,
            mode: CallbackMode.REQUIRED
        });
        supportedCallbackFunctions[1] = SupportedCallbackFunction({
            selector: BeforeTransferCallbackERC1155.beforeTransferERC1155.selector,
            mode: CallbackMode.OPTIONAL
        });
        supportedCallbackFunctions[2] = SupportedCallbackFunction({
            selector: BeforeBatchTransferCallbackERC1155.beforeBatchTransferERC1155.selector,
            mode: CallbackMode.OPTIONAL
        });
        supportedCallbackFunctions[3] = SupportedCallbackFunction({
            selector: BeforeBurnCallbackERC1155.beforeBurnERC1155.selector,
            mode: CallbackMode.OPTIONAL
        });
        supportedCallbackFunctions[4] = SupportedCallbackFunction({
            selector: BeforeApproveForAllCallback.beforeApproveForAll.selector,
            mode: CallbackMode.OPTIONAL
        });
        supportedCallbackFunctions[5] =
            SupportedCallbackFunction({selector: OnTokenURICallback.onTokenURI.selector, mode: CallbackMode.REQUIRED});
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Sets the contract URI of the contract.
     *  @dev Only callable by contract admin.
     *  @param uri The contract URI to set.
     */
    function setContractURI(string memory uri) external onlyOwner {
        _setupContractURI(uri);
    }

    /**
     *  @notice Mints tokens with a given tokenId. Calls the beforeMint hook.
     *  @dev Reverts if beforeMint hook is absent or unsuccessful.
     *  @param to The address to mint the token to.
     *  @param tokenId The tokenId to mint.
     *  @param value The amount of tokens to mint.
     *  @param data ABI encoded data to pass to the beforeMint hook.
     */
    function mint(address to, uint256 tokenId, uint256 value, bytes memory data) external payable {
        _beforeMint(to, tokenId, value, data);
        _mint(to, tokenId, value, "");

        _totalSupply[tokenId] += value;
    }

    /**
     *  @notice Burns given amount of tokens.
     *  @dev Calls the beforeBurn hook. Skips calling the hook if it doesn't exist.
     *  @param from Owner of the tokens
     *  @param tokenId The token ID of the NFTs to burn.
     *  @param value The amount of tokens to burn.
     *  @param data ABI encoded data to pass to the beforeBurn hook.
     */
    function burn(address from, uint256 tokenId, uint256 value, bytes memory data) external {
        _beforeBurn(from, tokenId, value, data);
        _burn(msg.sender, from, tokenId, value);

        _totalSupply[tokenId] -= value;
    }

    /**
     *  @notice Transfers ownership of an NFT from one address to another.
     *  @dev Overriden to call the beforeTransfer hook. Skips calling the hook if it doesn't exist.
     *  @param from The address to transfer from
     *  @param to The address to transfer to
     *  @param tokenId The token ID of the NFT
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, uint256 value, bytes calldata data)
        public
        override
    {
        _beforeTransfer(from, to, tokenId, value);
        super.safeTransferFrom(from, to, tokenId, value, data);
    }

    /**
     *  @notice Transfers ownership of an NFT from one address to another.
     *  @dev Overriden to call the beforeTransfer hook. Skips calling the hook if it doesn't exist.
     *  @param from The address to transfer from
     *  @param to The address to transfer to
     *  @param tokenIds The token ID of the NFT
     *  @param values The amount of NFTs to transfer
     *  @param data The calldata for the onERC1155Received callback function
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata tokenIds,
        uint256[] calldata values,
        bytes calldata data
    ) public override {
        _beforeBatchTransfer(from, to, tokenIds, values);
        super.safeBatchTransferFrom(from, to, tokenIds, values, data);
    }

    /**
     *  @notice Approves an address to transfer all NFTs. Reverts if caller is not owner or approved operator.
     *  @dev Overriden to call the beforeApprove hook. Skips calling the hook if it doesn't exist.
     *  @param operator The address to approve
     *  @param approved To grant or revoke approval
     */
    function setApprovalForAll(address operator, bool approved) public override {
        _beforeApproveForAll(msg.sender, operator, approved);
        super.setApprovalForAll(operator, approved);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Sets contract URI
    function _setupContractURI(string memory uri) internal {
        _contractURI = uri;
        emit ContractURIUpdated();
    }

    /*//////////////////////////////////////////////////////////////
                        CALLBACK INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Calls the beforeMint hook.
    function _beforeMint(address to, uint256 tokenId, uint256 value, bytes memory data) internal virtual {
        _executeCallbackFunction(
            BeforeMintCallbackERC1155.beforeMintERC1155.selector,
            abi.encodeCall(BeforeMintCallbackERC1155.beforeMintERC1155, (msg.sender, to, tokenId, value, data))
        );
    }

    /// @dev Calls the beforeTransfer hook, if installed.
    function _beforeTransfer(address from, address to, uint256 tokenId, uint256 value) internal virtual {
        _executeCallbackFunction(
            BeforeTransferCallbackERC1155.beforeTransferERC1155.selector,
            abi.encodeCall(BeforeTransferCallbackERC1155.beforeTransferERC1155, (msg.sender, from, to, tokenId, value))
        );
    }

    /// @dev Calls the beforeTransfer hook, if installed.
    function _beforeBatchTransfer(address from, address to, uint256[] calldata tokenIds, uint256[] calldata values)
        internal
        virtual
    {
        _executeCallbackFunction(
            BeforeBatchTransferCallbackERC1155.beforeBatchTransferERC1155.selector,
            abi.encodeCall(
                BeforeBatchTransferCallbackERC1155.beforeBatchTransferERC1155, (msg.sender, from, to, tokenIds, values)
            )
        );
    }

    /// @dev Calls the beforeBurn hook, if installed.
    function _beforeBurn(address from, uint256 tokenId, uint256 value, bytes memory data) internal virtual {
        _executeCallbackFunction(
            BeforeBurnCallbackERC1155.beforeBurnERC1155.selector,
            abi.encodeCall(BeforeBurnCallbackERC1155.beforeBurnERC1155, (msg.sender, from, tokenId, value, data))
        );
    }

    /// @dev Calls the beforeApprove hook, if installed.
    function _beforeApproveForAll(address from, address to, bool approved) internal virtual {
        _executeCallbackFunction(
            BeforeApproveForAllCallback.beforeApproveForAll.selector,
            abi.encodeCall(BeforeApproveForAllCallback.beforeApproveForAll, (msg.sender, from, to, approved))
        );
    }

    /// @dev Fetches token URI from the token metadata hook.
    function _getTokenURI(uint256 tokenId) internal view virtual returns (string memory tokenUri) {
        (, bytes memory returndata) = _executeCallbackFunctionView(
            OnTokenURICallback.onTokenURI.selector, abi.encodeCall(OnTokenURICallback.onTokenURI, (tokenId))
        );
        tokenUri = abi.decode(returndata, (string));
    }
}

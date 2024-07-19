// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Initializable} from "@solady/utils/Initializable.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";
import {ERC1155} from "@solady/tokens/ERC1155.sol";

import {ModularCore} from "../../ModularCore.sol";

import {CreatorToken} from "./CreatorToken/CreatorToken.sol";
import {TOKEN_TYPE_ERC1155} from "@limitbreak/permit-c/Constants.sol";
import {ITransferValidator} from "@limitbreak/creator-token-standards/interfaces/ITransferValidator.sol";

import {BeforeMintCallbackERC1155} from "../../callback/BeforeMintCallbackERC1155.sol";
import {BeforeBatchMintCallbackERC1155} from "../../callback/BeforeBatchMintCallbackERC1155.sol";
import {BeforeTransferCallbackERC1155} from "../../callback/BeforeTransferCallbackERC1155.sol";
import {BeforeBatchTransferCallbackERC1155} from "../../callback/BeforeBatchTransferCallbackERC1155.sol";
import {BeforeBurnCallbackERC1155} from "../../callback/BeforeBurnCallbackERC1155.sol";
import {BeforeApproveForAllCallback} from "../../callback/BeforeApproveForAllCallback.sol";
import {OnTokenURICallback} from "../../callback/OnTokenURICallback.sol";

contract ERC1155CoreInitializable is ERC1155, ModularCore, Multicallable, Initializable, CreatorToken {
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
    mapping(uint256 => uint256) private _totalSupply;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the contract URI is updated.
    event ContractURIUpdated();

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR & INITIALIZER
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory _name,
        string memory _symbol,
        string memory _contractURI,
        address _owner,
        address[] memory _extensions,
        bytes[] memory _extensionInstallData
    ) external payable initializer {
        // Set contract metadata
        name_ = _name;
        symbol_ = _symbol;
        _setupContractURI(_contractURI);
        _initializeOwner(_owner);

        // Install and initialize extensions
        require(_extensions.length == _extensionInstallData.length);
        for (uint256 i = 0; i < _extensions.length; i++) {
            _installExtension(_extensions[i], _extensionInstallData[i]);
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
    function contractURI() external view returns (string memory) {
        return contractURI_;
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
    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, ModularCore) returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC165 Interface ID for ERC165
            || interfaceId == 0xd9b67a26 // ERC165 Interface ID for ERC1155
            || interfaceId == 0x0e89341c // ERC165 Interface ID for ERC1155MetadataURI
            || interfaceId == 0xe8a3d485 // ERC-7572
            || interfaceId == 0x7f5828d0 // ERC-173
            || super.supportsInterface(interfaceId); // right-most ModularCore
    }

    function getSupportedCallbackFunctions()
        public
        pure
        override
        returns (SupportedCallbackFunction[] memory supportedCallbackFunctions)
    {
        supportedCallbackFunctions = new SupportedCallbackFunction[](7);
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
        supportedCallbackFunctions[6] = SupportedCallbackFunction({
            selector: BeforeBatchMintCallbackERC1155.beforeBatchMintERC1155.selector,
            mode: CallbackMode.REQUIRED
        });
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

    function setTransferValidator(address validator) external onlyOwner {
        _setTransferValidator(validator);
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

        _totalSupply[tokenId] += value;
        _mint(to, tokenId, value, "");
    }

    /**
     *  @notice Batch mints tokens. Calls the beforeBatchMint hook.
     *  @dev Reverts if beforeBatchMint hook is absent or unsuccessful.
     *  @param to The address to mint the token to.
     *  @param ids The tokenIds to mint.
     *  @param amounts The amounts of tokens to mint.
     *  @param data ABI encoded data to pass to the beforeBatchMint hook.
     */
    function batchMint(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        external
        payable
    {
        _beforeBatchMint(to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            _totalSupply[ids[i]] += amounts[i];
        }

        _batchMint(to, ids, amounts, "");
    }

    /**
     *  @notice Burns given amount of tokens.
     *  @dev Calls the beforeBurn hook. Skips calling the hook if it doesn't exist.
     *  @param from Owner of the tokens
     *  @param tokenId The token ID of the NFTs to burn.
     *  @param value The amount of tokens to burn.
     *  @param data ABI encoded data to pass to the beforeBurn hook.
     */
    function burn(address from, uint256 tokenId, uint256 value, bytes memory data) external payable {
        _beforeBurn(from, tokenId, value, data);

        _totalSupply[tokenId] -= value;
        _burn(msg.sender, from, tokenId, value);
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

    /**
     * @notice Returns the function selector for the transfer validator's validation function to be called
     * @notice for transaction simulation.
     */
    function getTransferValidationFunction() external pure returns (bytes4 functionSignature, bool isViewFunction) {
        functionSignature = bytes4(keccak256("validateTransfer(address,address,address,uint256,uint256)"));
        isViewFunction = true;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Sets contract URI
    function _setupContractURI(string memory _contractURI) internal {
        contractURI_ = _contractURI;
        emit ContractURIUpdated();
    }

    function _tokenType() internal pure override returns (uint16) {
        return uint16(TOKEN_TYPE_ERC1155);
    }

    /*//////////////////////////////////////////////////////////////
                        CALLBACK INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Calls the beforeMint hook.
    function _beforeMint(address to, uint256 tokenId, uint256 value, bytes memory data) internal virtual {
        _executeCallbackFunction(
            BeforeMintCallbackERC1155.beforeMintERC1155.selector,
            abi.encodeCall(BeforeMintCallbackERC1155.beforeMintERC1155, (to, tokenId, value, data))
        );
    }

    /// @dev Calls the beforeBatchMint hook.
    function _beforeBatchMint(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        virtual
    {
        _executeCallbackFunction(
            BeforeBatchMintCallbackERC1155.beforeBatchMintERC1155.selector,
            abi.encodeCall(BeforeBatchMintCallbackERC1155.beforeBatchMintERC1155, (to, ids, amounts, data))
        );
    }

    /// @dev Calls the beforeTransfer hook, if installed.
    function _beforeTransfer(address from, address to, uint256 tokenId, uint256 value) internal virtual {
        address transferValidator = getTransferValidator();
        if (transferValidator != address(0)) {
            ITransferValidator(transferValidator).validateTransfer(msg.sender, from, to, tokenId, value);
        }
        _executeCallbackFunction(
            BeforeTransferCallbackERC1155.beforeTransferERC1155.selector,
            abi.encodeCall(BeforeTransferCallbackERC1155.beforeTransferERC1155, (from, to, tokenId, value))
        );
    }

    /// @dev Calls the beforeTransfer hook, if installed.
    function _beforeBatchTransfer(address from, address to, uint256[] calldata tokenIds, uint256[] calldata values)
        internal
        virtual
    {
        address transferValidator = getTransferValidator();
        if (transferValidator != address(0)) {
            for (uint256 i = 0; i < tokenIds.length; i++) {
                ITransferValidator(transferValidator).validateTransfer(msg.sender, from, to, tokenIds[i], values[i]);
            }
        }
        _executeCallbackFunction(
            BeforeBatchTransferCallbackERC1155.beforeBatchTransferERC1155.selector,
            abi.encodeCall(BeforeBatchTransferCallbackERC1155.beforeBatchTransferERC1155, (from, to, tokenIds, values))
        );
    }

    /// @dev Calls the beforeBurn hook, if installed.
    function _beforeBurn(address from, uint256 tokenId, uint256 value, bytes memory data) internal virtual {
        _executeCallbackFunction(
            BeforeBurnCallbackERC1155.beforeBurnERC1155.selector,
            abi.encodeCall(BeforeBurnCallbackERC1155.beforeBurnERC1155, (from, tokenId, value, data))
        );
    }

    /// @dev Calls the beforeApprove hook, if installed.
    function _beforeApproveForAll(address from, address to, bool approved) internal virtual {
        _executeCallbackFunction(
            BeforeApproveForAllCallback.beforeApproveForAll.selector,
            abi.encodeCall(BeforeApproveForAllCallback.beforeApproveForAll, (from, to, approved))
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

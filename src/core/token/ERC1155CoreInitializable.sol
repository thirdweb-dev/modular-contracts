// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC1155} from "@solady/tokens/ERC1155.sol";

import {ECDSA} from "@solady/utils/ECDSA.sol";
import {EIP712} from "@solady/utils/EIP712.sol";
import {Initializable} from "@solady/utils/Initializable.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";

import {Core} from "../../Core.sol";

import {BeforeApproveForAllCallback} from "../../callback/BeforeApproveForAllCallback.sol";
import {BeforeBatchTransferCallbackERC1155} from "../../callback/BeforeBatchTransferCallbackERC1155.sol";
import {BeforeBurnCallbackERC1155} from "../../callback/BeforeBurnCallbackERC1155.sol";
import {BeforeMintCallbackERC1155} from "../../callback/BeforeMintCallbackERC1155.sol";
import {BeforeMintWithSignatureCallbackERC1155} from "../../callback/BeforeMintWithSignatureCallbackERC1155.sol";
import {BeforeTransferCallbackERC1155} from "../../callback/BeforeTransferCallbackERC1155.sol";
import {UpdateMetadataCallbackERC1155} from "../../callback/UpdateMetadataCallbackERC1155.sol";

import {OnTokenURICallback} from "../../callback/OnTokenURICallback.sol";

contract ERC1155CoreInitializable is ERC1155, Core, Multicallable, Initializable, EIP712 {

    using ECDSA for bytes32;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 private constant TYPEHASH_SIGNATURE_MINT_ERC1155 =
        keccak256("MintRequestERC1155(address to,uint256 tokenId,uint256 amount,string baseURI,bytes data)");

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
        address[] memory _modules,
        bytes[] memory _moduleInstallData
    ) external payable initializer {
        // Set contract metadata
        name_ = _name;
        symbol_ = _symbol;
        _setupContractURI(_contractURI);
        _initializeOwner(_owner);

        // Install and initialize modules
        require(_modules.length == _moduleInstallData.length);
        for (uint256 i = 0; i < _modules.length; i++) {
            _installModule(_modules[i], _moduleInstallData[i]);
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
    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, Core) returns (bool) {
        return interfaceId == 0xd9b67a26 // ERC165 Interface ID for ERC1155
            || interfaceId == 0x0e89341c // ERC165 Interface ID for ERC1155MetadataURI
            || interfaceId == 0xe8a3d485 // ERC-7572
            || interfaceId == 0x7f5828d0 // ERC-173
            || super.supportsInterface(interfaceId); // right-most Core
    }

    function getSupportedCallbackFunctions()
        public
        pure
        override
        returns (SupportedCallbackFunction[] memory supportedCallbackFunctions)
    {
        supportedCallbackFunctions = new SupportedCallbackFunction[](8);
        supportedCallbackFunctions[0] = SupportedCallbackFunction({
            selector: BeforeMintCallbackERC1155.beforeMintERC1155.selector,
            mode: CallbackMode.REQUIRED
        });
        supportedCallbackFunctions[1] = SupportedCallbackFunction({
            selector: BeforeMintWithSignatureCallbackERC1155.beforeMintWithSignatureERC1155.selector,
            mode: CallbackMode.REQUIRED
        });
        supportedCallbackFunctions[2] = SupportedCallbackFunction({
            selector: BeforeTransferCallbackERC1155.beforeTransferERC1155.selector,
            mode: CallbackMode.OPTIONAL
        });
        supportedCallbackFunctions[3] = SupportedCallbackFunction({
            selector: BeforeBatchTransferCallbackERC1155.beforeBatchTransferERC1155.selector,
            mode: CallbackMode.OPTIONAL
        });
        supportedCallbackFunctions[4] = SupportedCallbackFunction({
            selector: BeforeBurnCallbackERC1155.beforeBurnERC1155.selector,
            mode: CallbackMode.OPTIONAL
        });
        supportedCallbackFunctions[5] = SupportedCallbackFunction({
            selector: BeforeApproveForAllCallback.beforeApproveForAll.selector,
            mode: CallbackMode.OPTIONAL
        });
        supportedCallbackFunctions[6] =
            SupportedCallbackFunction({selector: OnTokenURICallback.onTokenURI.selector, mode: CallbackMode.REQUIRED});
        supportedCallbackFunctions[7] = SupportedCallbackFunction({
            selector: UpdateMetadataCallbackERC1155.updateMetadataERC1155.selector,
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

    /**
     *  @notice Mints tokens with a given tokenId. Calls the beforeMint hook.
     *  @dev Reverts if beforeMint hook is absent or unsuccessful.
     *  @param to The address to mint the token to.
     *  @param tokenId The tokenId to mint.
     *  @param amount The amount of tokens to mint.
     *  @param baseURI The base URI for the token metadata.
     *  @param data ABI encoded data to pass to the beforeMint hook.
     */
    function mint(address to, uint256 tokenId, uint256 amount, string calldata baseURI, bytes memory data)
        external
        payable
    {
        if (bytes(baseURI).length > 0) {
            _updateMetadata(to, tokenId, amount, baseURI);
        }
        _beforeMint(to, tokenId, amount, data);

        _totalSupply[tokenId] += amount;
        _mint(to, tokenId, amount, "");
    }

    /**
     *  @notice Mints tokens with a signature. Calls the beforeMintWithSignature hook.
     *  @dev Reverts if beforeMintWithSignature hook is absent or unsuccessful.
     *  @param to The address to mint the token to.
     *  @param tokenId The tokenId to mint.
     *  @param amount The amount of tokens to mint.
     *  @param baseURI The base URI for the token metadata.
     *  @param data ABI encoded data to pass to the beforeMintWithSignature hook.
     *  @param signature The signature produced from signing the minting request.
     */
    function mintWithSignature(
        address to,
        uint256 tokenId,
        uint256 amount,
        string calldata baseURI,
        bytes calldata data,
        bytes memory signature
    ) external payable {
        address signer = _hashTypedData(
            keccak256(
                abi.encode(
                    TYPEHASH_SIGNATURE_MINT_ERC1155, to, tokenId, amount, keccak256(bytes(baseURI)), keccak256(data)
                )
            )
        ).recover(signature);

        if (bytes(baseURI).length > 0) {
            _updateMetadata(to, tokenId, amount, baseURI);
        }
        _beforeMintWithSignature(to, tokenId, amount, data, signer);

        _totalSupply[tokenId] += amount;
        _mint(to, tokenId, amount, "");
    }

    /**
     *  @notice Burns given amount of tokens.
     *  @dev Calls the beforeBurn hook. Skips calling the hook if it doesn't exist.
     *  @param from Owner of the tokens
     *  @param tokenId The token ID of the NFTs to burn.
     *  @param amount The amount of tokens to burn.
     *  @param data ABI encoded data to pass to the beforeBurn hook.
     */
    function burn(address from, uint256 tokenId, uint256 amount, bytes memory data) external payable {
        _beforeBurn(from, tokenId, amount, data);

        _totalSupply[tokenId] -= amount;
        _burn(msg.sender, from, tokenId, amount);
    }

    /**
     *  @notice Transfers ownership of an NFT from one address to another.
     *  @dev Overriden to call the beforeTransfer hook. Skips calling the hook if it doesn't exist.
     *  @param from The address to transfer from
     *  @param to The address to transfer to
     *  @param tokenId The token ID of the NFT
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, uint256 amount, bytes calldata data)
        public
        override
    {
        _beforeTransfer(from, to, tokenId, amount);
        super.safeTransferFrom(from, to, tokenId, amount, data);
    }

    /**
     *  @notice Transfers ownership of an NFT from one address to another.
     *  @dev Overriden to call the beforeTransfer hook. Skips calling the hook if it doesn't exist.
     *  @param from The address to transfer from
     *  @param to The address to transfer to
     *  @param tokenIds The token ID of the NFT
     *  @param amounts The amount of NFTs to transfer
     *  @param data The calldata for the onERC1155Received callback function
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts,
        bytes calldata data
    ) public override {
        _beforeBatchTransfer(from, to, tokenIds, amounts);
        super.safeBatchTransferFrom(from, to, tokenIds, amounts, data);
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
    function _setupContractURI(string memory _contractURI) internal {
        contractURI_ = _contractURI;
        emit ContractURIUpdated();
    }

    /*//////////////////////////////////////////////////////////////
                        CALLBACK INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Calls the beforeMint hook.
    function _beforeMint(address to, uint256 tokenId, uint256 amount, bytes memory data) internal virtual {
        _executeCallbackFunction(
            BeforeMintCallbackERC1155.beforeMintERC1155.selector,
            abi.encodeCall(BeforeMintCallbackERC1155.beforeMintERC1155, (to, tokenId, amount, data))
        );
    }

    /// @dev Calls the beforeMintWithSignature hook.
    function _beforeMintWithSignature(address to, uint256 tokenId, uint256 amount, bytes calldata data, address signer)
        internal
        virtual
    {
        _executeCallbackFunction(
            BeforeMintWithSignatureCallbackERC1155.beforeMintWithSignatureERC1155.selector,
            abi.encodeCall(
                BeforeMintWithSignatureCallbackERC1155.beforeMintWithSignatureERC1155,
                (to, tokenId, amount, data, signer)
            )
        );
    }

    /// @dev Calls the beforeTransfer hook, if installed.
    function _beforeTransfer(address from, address to, uint256 tokenId, uint256 amount) internal virtual {
        _executeCallbackFunction(
            BeforeTransferCallbackERC1155.beforeTransferERC1155.selector,
            abi.encodeCall(BeforeTransferCallbackERC1155.beforeTransferERC1155, (from, to, tokenId, amount))
        );
    }

    /// @dev Calls the beforeTransfer hook, if installed.
    function _beforeBatchTransfer(address from, address to, uint256[] calldata tokenIds, uint256[] calldata amounts)
        internal
        virtual
    {
        _executeCallbackFunction(
            BeforeBatchTransferCallbackERC1155.beforeBatchTransferERC1155.selector,
            abi.encodeCall(BeforeBatchTransferCallbackERC1155.beforeBatchTransferERC1155, (from, to, tokenIds, amounts))
        );
    }

    /// @dev Calls the beforeBurn hook, if installed.
    function _beforeBurn(address from, uint256 tokenId, uint256 amount, bytes memory data) internal virtual {
        _executeCallbackFunction(
            BeforeBurnCallbackERC1155.beforeBurnERC1155.selector,
            abi.encodeCall(BeforeBurnCallbackERC1155.beforeBurnERC1155, (from, tokenId, amount, data))
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

    /// @dev Calls the updateMetadata hook, if installed.
    function _updateMetadata(address to, uint256 tokenId, uint256 amount, string calldata baseURI) internal virtual {
        _executeCallbackFunction(
            UpdateMetadataCallbackERC1155.updateMetadataERC1155.selector,
            abi.encodeCall(UpdateMetadataCallbackERC1155.updateMetadataERC1155, (to, tokenId, amount, baseURI))
        );
    }

    /// @dev Returns the domain name and version for EIP712.
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "ERC1155Core";
        version = "1";
    }

}

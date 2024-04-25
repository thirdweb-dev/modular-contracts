// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Ownable} from "@solady/auth/Ownable.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";
import {IERC721A, ERC721A, ERC721AQueryable} from "@erc721a/extensions/ERC721AQueryable.sol";

import {CoreContract} from "../CoreContract.sol";

import {BeforeMintHookERC721} from "../../hook/BeforeMintHookERC721.sol";
import {BeforeTransferHookERC721} from "../../hook/BeforeTransferHookERC721.sol";
import {BeforeBurnHookERC721} from "../../hook/BeforeBurnHookERC721.sol";
import {BeforeApproveHookERC721} from "../../hook/BeforeApproveHookERC721.sol";
import {BeforeApproveForAllHook} from "../../hook/BeforeApproveForAllHook.sol";
import {OnTokenURIHook} from "../../hook/OnTokenURIHook.sol";
import {OnRoyaltyInfoHook} from "../../hook/OnRoyaltyInfoHook.sol";

contract ERC721Core is ERC721AQueryable, CoreContract, Ownable, Multicallable {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The contract metadata URI of the contract.
    string private contractURI_;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the on initialize call fails.
    error ERC721CoreInitCallFailed();

    /// @notice Emitted when a hook call fails.
    error ERC721CoreCallbackFailed();

    /// @notice Emitted on an attempt to mint tokens when no beforeMint hook is installed.
    error ERC721CoreMintDisabled();

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the contract URI is updated.
    event ContractURIUpdated();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _contractURI,
        address _owner,
        address[] memory _extensionsToInstall,
        address _initCallTarget,
        bytes memory _initCalldata
    ) payable ERC721A(_name, _symbol) {
        // Set contract metadata
        _setupContractURI(_contractURI);

        // Set contract owner
        _setOwner(_owner);

        // External call upon core core contract initialization.
        if (_initCallTarget != address(0) && _initCalldata.length > 0) {
            (bool success, bytes memory returndata) = _initCallTarget.call{value: msg.value}(_initCalldata);
            if (!success) _revert(returndata, ERC721CoreInitCallFailed.selector);
        }

        // Install and initialize hooks
        for (uint256 i = 0; i < _extensionsToInstall.length; i++) {
            _installExtension(_extensionsToInstall[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Returns the contract URI of the contract.
     *  @return uri The contract URI of the contract.
     */
    function contractURI() external view returns (string memory) {
        return contractURI_;
    }

    /**
     *  @notice Returns the token metadata of an NFT.
     *  @dev Always returns metadata queried from the metadata source.
     *  @param _id The token ID of the NFT.
     *  @return metadata The URI to fetch metadata from.
     */
    function tokenURI(uint256 _id) public view override(ERC721A, IERC721A) returns (string memory) {
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
    function supportsInterface(bytes4 _interfaceId) public pure override(IERC721A, ERC721A) returns (bool) {
        return _interfaceId == 0x01ffc9a7 // ERC165 Interface ID for ERC165
            || _interfaceId == 0x80ac58cd // ERC165 Interface ID for ERC721
            || _interfaceId == 0x5b5e139f // ERC165 Interface ID for ERC721Metadata
            || _interfaceId == 0x2a55205a; // ERC165 Interface ID for ERC-2981
    }

    function getSupportedCallbackFunctions()
        public
        pure
        override
        returns (bytes4[] memory supportedCallbackFunctions)
    {
        supportedCallbackFunctions = new bytes4[](7);
        supportedCallbackFunctions[0] = BeforeMintHookERC721.beforeMintERC721.selector;
        supportedCallbackFunctions[1] = BeforeTransferHookERC721.beforeTransferERC721.selector;
        supportedCallbackFunctions[2] = BeforeBurnHookERC721.beforeBurnERC721.selector;
        supportedCallbackFunctions[3] = BeforeApproveHookERC721.beforeApproveERC721.selector;
        supportedCallbackFunctions[4] = BeforeApproveForAllHook.beforeApproveForAll.selector;
        supportedCallbackFunctions[5] = OnTokenURIHook.onTokenURI.selector;
        supportedCallbackFunctions[6] = OnRoyaltyInfoHook.onRoyaltyInfo.selector;
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
     *  @param _data ABI encoded data to pass to the beforeMint hook.
     */
    function mint(address _to, uint256 _quantity, bytes calldata _data) external payable {
        _beforeMint(_to, _quantity, _data);
        _mint(_to, _quantity);
    }

    /**
     *  @notice Burns an NFT.
     *  @dev Calls the beforeBurn hook. Skips calling the hook if it doesn't exist.
     *  @param _tokenId The token ID of the NFT to burn.
     *  @param _data ABI encoded data to pass to the beforeBurn hook.
     */
    function burn(uint256 _tokenId, bytes calldata _data) external {
        _beforeBurn(msg.sender, _tokenId, _data);
        _burn(_tokenId, true);
    }

    /**
     *  @notice Transfers ownership of an NFT from one address to another.
     *  @dev Overriden to call the beforeTransfer hook. Skips calling the hook if it doesn't exist.
     *  @param _from The address to transfer from
     *  @param _to The address to transfer to
     *  @param _id The token ID of the NFT
     */
    function transferFrom(address _from, address _to, uint256 _id) public payable override(ERC721A, IERC721A) {
        _beforeTransfer(_from, _to, _id);
        super.transferFrom(_from, _to, _id);
    }

    /**
     *  @notice Approves an address to transfer a specific NFT. Reverts if caller is not owner or approved operator.
     *  @dev Overriden to call the beforeApprove hook. Skips calling the hook if it doesn't exist.
     *  @param _spender The address to approve
     *  @param _id The token ID of the NFT
     */
    function approve(address _spender, uint256 _id) public payable override(ERC721A, IERC721A) {
        _beforeApprove(msg.sender, _spender, _id, true);
        super.approve(_spender, _id);
    }

    /**
     *  @notice Approves or revokes approval from an operator to transfer or issue approval for all of the caller's NFTs.
     *  @param _operator The address to approve or revoke approval from
     *  @param _approved Whether the operator is approved
     */
    function setApprovalForAll(address _operator, bool _approved) public override(ERC721A, IERC721A) {
        _beforeApproveForAll(msg.sender, _operator, _approved);
        super.setApprovalForAll(_operator, _approved);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _isAuthorizedToInstallExtensions(address _target) internal view override returns (bool) {
        return _target == owner();
    }

    function _isAuthorizedToCallExtensionFunctions(address _target) internal view override returns (bool) {
        return _target == owner();
    }

    /// @dev Sets contract URI
    function _setupContractURI(string memory _contractURI) internal {
        contractURI_ = _contractURI;
        emit ContractURIUpdated();
    }

    /*//////////////////////////////////////////////////////////////
                        HOOKS INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Calls the beforeMint hook.
    function _beforeMint(address _to, uint256 _quantity, bytes calldata _data) internal virtual {
        address hook = getCallbackFunctionImplementation(BeforeMintHookERC721.beforeMintERC721.selector);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) = hook.call{value: msg.value}(
                abi.encodeWithSelector(BeforeMintHookERC721.beforeMintERC721.selector, _to, _quantity, _data)
            );
            if (!success) _revert(returndata, ERC721CoreCallbackFailed.selector);
        } else {
            revert ERC721CoreMintDisabled();
        }
    }

    /// @dev Calls the beforeTransfer hook, if installed.
    function _beforeTransfer(address _from, address _to, uint256 _tokenId) internal virtual {
        address hook = getCallbackFunctionImplementation(BeforeTransferHookERC721.beforeTransferERC721.selector);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) = hook.call{value: msg.value}(
                abi.encodeWithSelector(BeforeTransferHookERC721.beforeTransferERC721.selector, _from, _to, _tokenId)
            );
            if (!success) _revert(returndata, ERC721CoreCallbackFailed.selector);
        }
    }

    /// @dev Calls the beforeBurn hook, if installed.
    function _beforeBurn(address _operator, uint256 _tokenId, bytes calldata _data) internal virtual {
        address hook = getCallbackFunctionImplementation(BeforeBurnHookERC721.beforeBurnERC721.selector);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) = hook.call{value: msg.value}(
                abi.encodeWithSelector(BeforeBurnHookERC721.beforeBurnERC721.selector, _operator, _tokenId, _data)
            );
            if (!success) _revert(returndata, ERC721CoreCallbackFailed.selector);
        }
    }

    /// @dev Calls the beforeApprove hook, if installed.
    function _beforeApprove(address _from, address _to, uint256 _tokenId, bool _approve) internal virtual {
        address hook = getCallbackFunctionImplementation(BeforeApproveHookERC721.beforeApproveERC721.selector);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) = hook.call{value: msg.value}(
                abi.encodeWithSelector(
                    BeforeApproveHookERC721.beforeApproveERC721.selector, _from, _to, _tokenId, _approve
                )
            );
            if (!success) _revert(returndata, ERC721CoreCallbackFailed.selector);
        }
    }

    /// @dev Calls the beforeApprove hook, if installed.
    function _beforeApproveForAll(address _from, address _to, bool _approve) internal virtual {
        address hook = getCallbackFunctionImplementation(BeforeApproveForAllHook.beforeApproveForAll.selector);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) = hook.call{value: msg.value}(
                abi.encodeWithSelector(BeforeApproveHookERC721.beforeApproveERC721.selector, _from, _to, _approve)
            );
            if (!success) _revert(returndata, ERC721CoreCallbackFailed.selector);
        }
    }

    /// @dev Fetches token URI from the token metadata hook.
    function _getTokenURI(uint256 _tokenId) internal view virtual returns (string memory uri) {
        address hook = getCallbackFunctionImplementation(OnTokenURIHook.onTokenURI.selector);

        if (hook != address(0)) {
            uri = OnTokenURIHook(hook).onTokenURI(_tokenId);
        }
    }

    /// @dev Fetches royalty info from the royalty hook.
    function _getRoyaltyInfo(uint256 _tokenId, uint256 _salePrice)
        internal
        view
        virtual
        returns (address receiver, uint256 royaltyAmount)
    {
        address hook = getCallbackFunctionImplementation(OnRoyaltyInfoHook.onRoyaltyInfo.selector);

        if (hook != address(0)) {
            (receiver, royaltyAmount) = OnRoyaltyInfoHook(hook).onRoyaltyInfo(_tokenId, _salePrice);
        }
    }
}

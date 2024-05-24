// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

import {Initializable} from "@solady/utils/Initializable.sol";

import {ModularCoreUpgradeable} from "../../ModularCoreUpgradeable.sol";

import {ERC20} from "@solady/tokens/ERC20.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";

import {BeforeMintCallbackERC20} from "../../callback/BeforeMintCallbackERC20.sol";
import {BeforeBurnCallbackERC20} from "../../callback/BeforeBurnCallbackERC20.sol";
import {BeforeApproveCallbackERC20} from "../../callback/BeforeApproveCallbackERC20.sol";
import {BeforeTransferCallbackERC20} from "../../callback/BeforeTransferCallbackERC20.sol";

contract ERC20CoreInitializable is ERC20, ModularCoreUpgradeable, Multicallable, Initializable {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The name of the token.
    string private _name;

    /// @notice The symbol of the token.
    string private _symbol;

    /// @notice The contract metadata URI of the contract.
    string private _contractURI;

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

        // Install and initialize extensions
        require(extensions.length == extensions.length);
        for (uint256 i = 0; i < extensions.length; i++) {
            _installExtension(extensions[i], extensionInstallData[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the name of the token.
    function name() public view override returns (string memory) {
        return _name;
    }

    /// @notice Returns the symbol of the token.
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /**
     *  @notice Returns the contract URI of the contract.
     *  @return uri The contract URI of the contract.
     */
    function contractURI() external view returns (string memory) {
        return _contractURI;
    }

    function getSupportedCallbackFunctions()
        public
        pure
        override
        returns (SupportedCallbackFunction[] memory supportedCallbackFunctions)
    {
        supportedCallbackFunctions = new SupportedCallbackFunction[](4);
        supportedCallbackFunctions[0] = SupportedCallbackFunction({
            selector: BeforeMintCallbackERC20.beforeMintERC20.selector,
            mode: CallbackMode.REQUIRED
        });
        supportedCallbackFunctions[1] = SupportedCallbackFunction({
            selector: BeforeTransferCallbackERC20.beforeTransferERC20.selector,
            mode: CallbackMode.OPTIONAL
        });
        supportedCallbackFunctions[2] = SupportedCallbackFunction({
            selector: BeforeBurnCallbackERC20.beforeBurnERC20.selector,
            mode: CallbackMode.OPTIONAL
        });
        supportedCallbackFunctions[3] = SupportedCallbackFunction({
            selector: BeforeApproveCallbackERC20.beforeApproveERC20.selector,
            mode: CallbackMode.OPTIONAL
        });
    }

    /*//////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Sets the contract URI of the contract.
     *  @dev Only callable by contract admin.
     *  @param contractURI The contract URI to set.
     */
    function setContractURI(string memory contractURI) external onlyOwner {
        _setupContractURI(contractURI);
    }

    /**
     *  @notice Mints tokens. Calls the beforeMint hook.
     *  @dev Reverts if beforeMint hook is absent or unsuccessful.
     *  @param to The address to mint the tokens to.
     *  @param amount The amount of tokens to mint.
     *  @param data ABI encoded data to pass to the beforeMintERC20 hook.
     */
    function mint(address to, uint256 amount, bytes calldata data) external payable {
        _beforeMint(to, amount, data);
        _mint(to, amount);
    }

    /**
     *  @notice Burns tokens.
     *  @dev Calls the beforeBurn hook. Skips calling the hook if it doesn't exist.
     *  @param from The address to burn tokens from.
     *  @param amount The amount of tokens to burn.
     *  @param data ABI encoded arguments to pass to the beforeBurnERC20 hook.
     */
    function burn(address from, uint256 amount, bytes calldata data) external {
        _beforeBurn(from, amount, data);

        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
    }

    /**
     *  @notice Transfers tokens to a recipient.
     *  @param to The address to transfer tokens to.
     *  @param amount The quantity of tokens to transfer.
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        _beforeTransfer(msg.sender, to, amount);
        return super.transfer(to, amount);
    }

    /**
     *  @notice Transfers tokens from a sender to a recipient.
     *  @param from The address to transfer tokens from.
     *  @param to The address to transfer tokens to.
     *  @param amount The quantity of tokens to transfer.
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _beforeTransfer(from, to, amount);
        return super.transferFrom(from, to, amount);
    }

    /**
     *  @notice Approves a spender to spend tokens on behalf of an owner.
     *  @param spender The address to approve spending on behalf of the token owner.
     *  @param amount The quantity of tokens to approve.
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        _beforeApprove(msg.sender, spender, amount);
        return super.approve(spender, amount);
    }

    /**
     * @notice Sets allowance based on token owner's signed approval.
     *
     * See https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     *
     *  @param owner The account approving the tokens
     *  @param spender The address to approve
     *  @param value Amount of tokens to approve
     */
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        public
        override
    {
        _beforeApprove(owner, spender, value);
        super.permit(owner, spender, value, deadline, v, r, s);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Sets contract URI
    function _setupContractURI(string memory contractURI) internal {
        _contractURI = contractURI;
        emit ContractURIUpdated();
    }

    /*//////////////////////////////////////////////////////////////
                          CALLBACK INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Calls the beforeMint hook.
    function _beforeMint(address to, uint256 amount, bytes calldata data) internal virtual {
        _executeCallbackFunction(
            BeforeMintCallbackERC20.beforeMintERC20.selector,
            abi.encodeCall(BeforeMintCallbackERC20.beforeMintERC20, (msg.sender, to, amount, data))
        );
    }

    /// @dev Calls the beforeTransfer hook, if installed.
    function _beforeTransfer(address from, address to, uint256 amount) internal virtual {
        _executeCallbackFunction(
            BeforeTransferCallbackERC20.beforeTransferERC20.selector,
            abi.encodeCall(BeforeTransferCallbackERC20.beforeTransferERC20, (msg.sender, from, to, amount))
        );
    }

    /// @dev Calls the beforeBurn hook, if installed.
    function _beforeBurn(address from, uint256 amount, bytes calldata data) internal virtual {
        _executeCallbackFunction(
            BeforeBurnCallbackERC20.beforeBurnERC20.selector,
            abi.encodeCall(BeforeBurnCallbackERC20.beforeBurnERC20, (msg.sender, from, amount, data))
        );
    }

    /// @dev Calls the beforeApprove hook, if installed.
    function _beforeApprove(address from, address to, uint256 amount) internal virtual {
        _executeCallbackFunction(
            BeforeApproveCallbackERC20.beforeApproveERC20.selector,
            abi.encodeCall(BeforeApproveCallbackERC20.beforeApproveERC20, (msg.sender, from, to, amount))
        );
    }
}

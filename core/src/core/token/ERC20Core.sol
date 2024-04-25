// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Ownable} from "@solady/auth/Ownable.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";
import {ERC20} from "@solady/tokens/ERC20.sol";

import {CoreContract} from "../CoreContract.sol";

import {BeforeMintCallbackERC20} from "../../callback/BeforeMintCallbackERC20.sol";
import {BeforeApproveCallbackERC20} from "../../callback/BeforeApproveCallbackERC20.sol";
import {BeforeTransferCallbackERC20} from "../../callback/BeforeTransferCallbackERC20.sol";
import {BeforeBurnCallbackERC20} from "../../callback/BeforeBurnCallbackERC20.sol";

contract ERC20Core is ERC20, CoreContract, Ownable, Multicallable {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The name of the token.
    string private name_;

    /// @notice The symbol of the token.
    string private symbol_;

    /// @notice The contract metadata URI of the contract.
    string private contractURI_;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the on initialize call fails.
    error ERC20CoreInitCallFailed();

    /// @notice Emitted when a hook call fails.
    error ERC20CoreCallbackFailed();

    /// @notice Emitted on an attempt to mint tokens when no beforeMint hook is installed.
    error ERC20CoreMintDisabled();

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
    ) payable {
        // Set contract metadata
        name_ = _name;
        symbol_ = _symbol;
        _setupContractURI(_contractURI);

        // Set contract owner
        _setOwner(_owner);

        // External call upon core core contract initialization.
        if (_initCallTarget != address(0) && _initCalldata.length > 0) {
            (bool success, bytes memory returndata) = _initCallTarget.call{value: msg.value}(_initCalldata);
            if (!success) _revert(returndata, ERC20CoreInitCallFailed.selector);
        }

        // Install and initialize hooks
        for (uint256 i = 0; i < _extensionsToInstall.length; i++) {
            _installExtension(_extensionsToInstall[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the name of the token.
    function name() public view override returns (string memory) {
        return name_;
    }

    /// @notice Returns the symbol of the token.
    function symbol() public view override returns (string memory) {
        return symbol_;
    }

    /**
     *  @notice Returns the contract URI of the contract.
     *  @return uri The contract URI of the contract.
     */
    function contractURI() external view returns (string memory) {
        return contractURI_;
    }

    function getSupportedCallbackFunctions()
        public
        pure
        override
        returns (bytes4[] memory supportedCallbackFunctions)
    {
        supportedCallbackFunctions = new bytes4[](4);

        supportedCallbackFunctions[0] = BeforeMintCallbackERC20.beforeMintERC20.selector;
        supportedCallbackFunctions[1] = BeforeTransferCallbackERC20.beforeTransferERC20.selector;
        supportedCallbackFunctions[2] = BeforeBurnCallbackERC20.beforeBurnERC20.selector;
        supportedCallbackFunctions[3] = BeforeApproveCallbackERC20.beforeApproveERC20.selector;
    }

    /*//////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Sets the contract URI of the contract.
     *  @dev Only callable by contract admin.
     *  @param _contractURI The contract URI to set.
     */
    function setContractURI(string memory _contractURI) external onlyOwner {
        _setupContractURI(_contractURI);
    }

    /**
     *  @notice Mints tokens. Calls the beforeMint hook.
     *  @dev Reverts if beforeMint hook is absent or unsuccessful.
     *  @param _to The address to mint the tokens to.
     *  @param _amount The amount of tokens to mint.
     *  @param _data ABI encoded data to pass to the beforeMintERC20 hook.
     */
    function mint(address _to, uint256 _amount, bytes calldata _data) external payable {
        _beforeMint(_to, _amount, _data);
        _mint(_to, _amount);
    }

    /**
     *  @notice Burns tokens.
     *  @dev Calls the beforeBurn hook. Skips calling the hook if it doesn't exist.
     *  @param _amount The amount of tokens to burn.
     *  @param _data ABI encoded arguments to pass to the beforeBurnERC20 hook.
     */
    function burn(uint256 _amount, bytes calldata _data) external {
        _beforeBurn(msg.sender, _amount, _data);
        _burn(msg.sender, _amount);
    }

    /**
     *  @notice Transfers tokens from a sender to a recipient.
     *  @param _from The address to transfer tokens from.
     *  @param _to The address to transfer tokens to.
     *  @param _amount The quantity of tokens to transfer.
     */
    function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
        _beforeTransfer(_from, _to, _amount);
        return super.transferFrom(_from, _to, _amount);
    }

    /**
     *  @notice Approves a spender to spend tokens on behalf of an owner.
     *  @param _spender The address to approve spending on behalf of the token owner.
     *  @param _amount The quantity of tokens to approve.
     */
    function approve(address _spender, uint256 _amount) public override returns (bool) {
        _beforeApprove(msg.sender, _spender, _amount);
        return super.approve(_spender, _amount);
    }

    /**
     * @notice Sets allowance based on token owner's signed approval.
     *
     * See https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     *
     *  @param _owner The account approving the tokens
     *  @param _spender The address to approve
     *  @param _value Amount of tokens to approve
     */
    function permit(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public override {
        _beforeApprove(_owner, _spender, _value);
        super.permit(_owner, _spender, _value, _deadline, _v, _r, _s);
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
                          CALLBACK INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Calls the beforeMint hook.
    function _beforeMint(address _to, uint256 _amount, bytes calldata _data) internal virtual {
        address extension = getCallbackFunctionImplementation(BeforeMintCallbackERC20.beforeMintERC20.selector);

        if (extension != address(0)) {
            (bool success, bytes memory returndata) = extension.call{value: msg.value}(
                abi.encodeWithSelector(BeforeMintCallbackERC20.beforeMintERC20.selector, _to, _amount, _data)
            );

            if (!success) _revert(returndata, ERC20CoreCallbackFailed.selector);
        } else {
            // Revert if beforeMint hook is not installed to disable un-permissioned minting.
            revert ERC20CoreMintDisabled();
        }
    }

    /// @dev Calls the beforeTransfer hook, if installed.
    function _beforeTransfer(address _from, address _to, uint256 _amount) internal virtual {
        address extension = getCallbackFunctionImplementation(BeforeTransferCallbackERC20.beforeTransferERC20.selector);

        if (extension != address(0)) {
            (bool success, bytes memory returndata) = extension.call(
                abi.encodeWithSelector(BeforeTransferCallbackERC20.beforeTransferERC20.selector, _from, _to, _amount)
            );
            if (!success) _revert(returndata, ERC20CoreCallbackFailed.selector);
        }
    }

    /// @dev Calls the beforeBurn hook, if installed.
    function _beforeBurn(address _from, uint256 _amount, bytes calldata _data) internal virtual {
        address extension = getCallbackFunctionImplementation(BeforeBurnCallbackERC20.beforeBurnERC20.selector);

        if (extension != address(0)) {
            (bool success, bytes memory returndata) = extension.call{value: msg.value}(
                abi.encodeWithSelector(BeforeBurnCallbackERC20.beforeBurnERC20.selector, _from, _amount, _data)
            );
            if (!success) _revert(returndata, ERC20CoreCallbackFailed.selector);
        }
    }

    /// @dev Calls the beforeApprove hook, if installed.
    function _beforeApprove(address _from, address _to, uint256 _amount) internal virtual {
        address extension = getCallbackFunctionImplementation(BeforeApproveCallbackERC20.beforeApproveERC20.selector);

        if (extension != address(0)) {
            (bool success, bytes memory returndata) = extension.call(
                abi.encodeWithSelector(BeforeApproveCallbackERC20.beforeApproveERC20.selector, _from, _to, _amount)
            );
            if (!success) _revert(returndata, ERC20CoreCallbackFailed.selector);
        }
    }
}

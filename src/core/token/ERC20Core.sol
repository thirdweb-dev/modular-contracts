// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Ownable} from "@solady/auth/Ownable.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";
import {ERC20} from "@solady/tokens/ERC20.sol";

import {HookInstaller} from "../HookInstaller.sol";

import {IERC20HookInstaller} from "../../interface/hook/IERC20HookInstaller.sol";
import {IERC20Hook} from "../../interface/hook/IERC20Hook.sol";
import {IERC7572} from "../../interface/eip/IERC7572.sol";

contract ERC20Core is ERC20, HookInstaller, Ownable, Multicallable, IERC7572, IERC20HookInstaller {
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
    error ERC20CoreOnInitializeCallFailed();

    /// @notice Emitted when a hook initialization call fails.
    error ERC20CoreHookInitializeCallFailed();

    /// @notice Emitted when a hook call fails.
    error ERC20CoreHookCallFailed();

    /// @notice Emitted when insufficient value is sent in the constructor.
    error ERC20CoreInsufficientValueInConstructor();

    /// @notice Emitted on an attempt to mint tokens when no beforeMint hook is installed.
    error ERC20CoreMintDisabled();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Initializes the ERC20 token.
     *
     *  @param _name The name of the token.
     *  @param _symbol The symbol of the token.
     *  @param _contractURI The contract URI of the token.
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

        // Initialize the core token
        if (_onInitializeCall.target != address(0)) {
            if (constructorValue < _onInitializeCall.value) revert ERC20CoreInsufficientValueInConstructor();
            constructorValue -= _onInitializeCall.value;

            (bool successOnInitialize, bytes memory returndataOnInitialize) =
                _onInitializeCall.target.call{value: _onInitializeCall.value}(_onInitializeCall.data);

            if (!successOnInitialize) _revert(returndataOnInitialize, ERC20CoreOnInitializeCallFailed.selector);
        }

        // Install and initialize hooks
        bool successHookInstall;
        bytes memory returndataHookInstall;

        for (uint256 i = 0; i < _hooksToInstall.length; i++) {
            if (constructorValue < _hooksToInstall[i].initCallValue) revert ERC20CoreInsufficientValueInConstructor();
            constructorValue -= _onInitializeCall.value;

            if (address(_hooksToInstall[i].hook) == address(0)) {
                revert HookInstallerInvalidHook();
            }

            _installHook(_hooksToInstall[i].hook);

            if (_hooksToInstall[i].initCalldata.length > 0) {
                (successHookInstall, returndataHookInstall) = address(_hooksToInstall[i].hook).call{
                    value: _hooksToInstall[i].initCallValue
                }(_hooksToInstall[i].initCalldata);

                if (!successHookInstall) _revert(returndataHookInstall, ERC20CoreHookInitializeCallFailed.selector);
            }
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
    function contractURI() external view override returns (string memory) {
        return contractURI_;
    }

    /// @notice Returns all of the contract's hooks and their implementations.
    function getAllHooks() external view returns (ERC20Hooks memory hooks) {
        hooks = ERC20Hooks({
            beforeMint: getHookImplementation(BEFORE_MINT_FLAG),
            beforeTransfer: getHookImplementation(BEFORE_TRANSFER_FLAG),
            beforeBurn: getHookImplementation(BEFORE_BURN_FLAG),
            beforeApprove: getHookImplementation(BEFORE_APPROVE_FLAG)
        });
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
     *  @param _encodedBeforeMintArgs ABI encoded arguments to pass to the beforeMint hook.
     */
    function mint(address _to, uint256 _amount, bytes memory _encodedBeforeMintArgs) external payable {
        uint256 quantityToMint = _beforeMint(_to, _amount, _encodedBeforeMintArgs);
        _mint(_to, quantityToMint);
    }

    /**
     *  @notice Burns tokens.
     *  @dev Calls the beforeBurn hook. Skips calling the hook if it doesn't exist.
     *  @param _amount The amount of tokens to burn.
     *  @param _encodedBeforeBurnArgs ABI encoded arguments to pass to the beforeBurn hook.
     */
    function burn(uint256 _amount, bytes memory _encodedBeforeBurnArgs) external {
        _beforeBurn(msg.sender, _amount, _encodedBeforeBurnArgs);
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

    /// @dev Returns whether the caller can update hooks.
    function _canUpdateHooks(address _caller) internal view override returns (bool) {
        return _caller == owner();
    }

    /// @dev Returns whether the caller can write to hooks.
    function _canWriteToHooks(address _caller) internal view override returns (bool) {
        return _caller == owner();
    }

    /// @dev Should return the max flag that represents a hook.
    function _maxHookFlag() internal pure override returns (uint8) {
        return uint8(BEFORE_APPROVE_FLAG);
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
    function _beforeMint(address _to, uint256 _amount, bytes memory _data)
        internal
        virtual
        returns (uint256 quantityToMint)
    {
        address hook = getHookImplementation(BEFORE_MINT_FLAG);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) =
                hook.call{value: msg.value}(abi.encodeWithSelector(IERC20Hook.beforeMint.selector, _to, _amount, _data));

            if (!success) _revert(returndata, ERC20CoreHookCallFailed.selector);
            quantityToMint = abi.decode(returndata, (uint256));
        } else {
            revert ERC20CoreMintDisabled();
        }
    }

    /// @dev Calls the beforeTransfer hook, if installed.
    function _beforeTransfer(address _from, address _to, uint256 _amount) internal virtual {
        address hook = getHookImplementation(BEFORE_TRANSFER_FLAG);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) =
                hook.call(abi.encodeWithSelector(IERC20Hook.beforeTransfer.selector, _from, _to, _amount));
            if (!success) _revert(returndata, ERC20CoreHookCallFailed.selector);
        }
    }

    /// @dev Calls the beforeBurn hook, if installed.
    function _beforeBurn(address _from, uint256 _amount, bytes memory _encodedBeforeBurnArgs) internal virtual {
        address hook = getHookImplementation(BEFORE_BURN_FLAG);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) = hook.call{value: msg.value}(
                abi.encodeWithSelector(IERC20Hook.beforeBurn.selector, _from, _amount, _encodedBeforeBurnArgs)
            );
            if (!success) _revert(returndata, ERC20CoreHookCallFailed.selector);
        }
    }

    /// @dev Calls the beforeApprove hook, if installed.
    function _beforeApprove(address _from, address _to, uint256 _amount) internal virtual {
        address hook = getHookImplementation(BEFORE_APPROVE_FLAG);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) =
                hook.call(abi.encodeWithSelector(IERC20Hook.beforeApprove.selector, _from, _to, _amount));
            if (!success) _revert(returndata, ERC20CoreHookCallFailed.selector);
        }
    }
}

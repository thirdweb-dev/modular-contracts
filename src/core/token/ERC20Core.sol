// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Initializable} from "@solady/utils/Initializable.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";
import {Ownable} from "@solady/auth/Ownable.sol";

import {IERC7572} from "../../interface/eip/IERC7572.sol";
import {IERC20Hook} from "../../interface/hook/IERC20Hook.sol";
import {IERC20HookInstaller} from "../../interface/hook/IERC20HookInstaller.sol";
import {IInitCall} from "../../interface/common/IInitCall.sol";
import {ERC20Initializable} from "./ERC20Initializable.sol";
import {IHook, HookInstaller} from "../../core/HookInstaller.sol";

contract ERC20Core is
    Initializable,
    Multicallable,
    Ownable,
    ERC20Initializable,
    HookInstaller,
    IInitCall,
    IERC20HookInstaller,
    IERC7572
{
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted on an attempt to mint tokens when either beforeMint hook is absent or unsuccessful.
    error ERC20CoreMintingDisabled();

    /// @notice Emitted when an unauthorized signer permits a spender to spend on an owner's their behalf.
    error ERC20PermitInvalidSigner();

    /// @notice Emitted on an attempt to permit approve tokens past the permit deadline.
    error ERC20PermitDeadlineExpired();

    /// @notice Emitted on a failed attempt to initialize the contract.
    error ERC20CoreInitializationFailed();

    /// @notice Emitted on failed attempt to call a hook.
    error ERC20CoreHookCallFailed();

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

    /// @notice The EIP-2612 permit typehash.
    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /*//////////////////////////////////////////////////////////////
                                  STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The contract URI of the contract.
    string private contractURI_;
    /// @notice nonces for EIP-2612 Permit functionality.
    mapping(address => uint256) private nonces_;

    /*//////////////////////////////////////////////////////////////
                      CONSTRUCTOR + INITIALIZE
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    /**
     *  @notice Initializes the ERC-20 Core contract.
     *  @param _hooks The hooks to install.
     *  @param _owner The owner of the contract.
     *  @param _name The name of the token collection.
     *  @param _symbol The symbol of the token collection.
     *  @param _contractURI Contract URI.
     */
    function initialize(
        InitCall calldata _initCall,
        address[] memory _hooks,
        address _owner,
        string memory _name,
        string memory _symbol,
        string memory _contractURI
    ) external initializer {
        _setupContractURI(_contractURI);
        __ERC20_init(_name, _symbol);
        _setOwner(_owner);

        uint256 len = _hooks.length;
        for (uint256 i = 0; i < len; i++) {
            _installHook(IHook(_hooks[i]));
        }

        if (_initCall.target != address(0)) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, bytes memory returnData) = _initCall.target.call{value: _initCall.value}(_initCall.data);
            if (!success) {
                if (returnData.length > 0) {
                    // solhint-disable-next-line no-inline-assembly
                    assembly {
                        revert(add(returnData, 32), mload(returnData))
                    }
                } else {
                    revert ERC20CoreInitializationFailed();
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
      //////////////////////////////////////////////////////////////*/

    /// @notice Returns all of the contract's hooks and their implementations.
    function getAllHooks() external view returns (ERC20Hooks memory hooks) {
        hooks = ERC20Hooks({
            beforeMint: getHookImplementation(BEFORE_MINT_FLAG),
            beforeTransfer: getHookImplementation(BEFORE_TRANSFER_FLAG),
            beforeBurn: getHookImplementation(BEFORE_BURN_FLAG),
            beforeApprove: getHookImplementation(BEFORE_APPROVE_FLAG)
        });
    }

    /**
     *  @notice Returns the contract URI of the contract.
     *  @return uri The contract URI of the contract.
     */
    function contractURI() external view override returns (string memory) {
        return contractURI_;
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

    /*//////////////////////////////////////////////////////////////
                          EIP 2612 related functions
      //////////////////////////////////////////////////////////////*/

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
    ) public {
        _beforeApprove(_owner, _spender, _value);

        if (_deadline < block.timestamp) {
            revert ERC20PermitDeadlineExpired();
        }

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        computeDomainSeparator(),
                        keccak256(abi.encode(PERMIT_TYPEHASH, _owner, _spender, _value, nonces_[_owner]++, _deadline))
                    )
                ),
                _v,
                _r,
                _s
            );

            if (recoveredAddress == address(0) || recoveredAddress != _owner) {
                revert ERC20PermitInvalidSigner();
            }

            super._approve(_owner, _spender, _value);
        }
    }

    /**
     * @notice Returns the current nonce for token owner.
     *
     * See https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function nonces(address owner) external view returns (uint256) {
        return nonces_[owner];
    }

    /**
     * @notice Returns the domain separator used in the encoding of the signature for permit.
     *
     * See https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                              INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the domain separator used in the encoding of the signature for permit.
    function computeDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name())),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /// @dev Sets contract URI
    function _setupContractURI(string memory _uri) internal {
        contractURI_ = _uri;
        emit ContractURIUpdated();
    }

    /// @dev Returns whether the given caller can update hooks.
    function _canUpdateHooks(address _caller) internal view override returns (bool) {
        return _caller == owner();
    }

    /// @dev Returns whether the caller can write to hooks.
    function _canWriteToHooks(address _caller) internal view override returns (bool) {
        return _caller == owner();
    }

    /// @dev Should return the max flag that represents a hook.
    function _maxHookFlag() internal pure override returns (uint256) {
        return BEFORE_APPROVE_FLAG;
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

            if (!success) _revert(returndata);
            quantityToMint = abi.decode(returndata, (uint256));
        } else {
            revert ERC20CoreMintingDisabled();
        }
    }

    /// @dev Calls the beforeTransfer hook, if installed.
    function _beforeTransfer(address _from, address _to, uint256 _amount) internal virtual {
        address hook = getHookImplementation(BEFORE_TRANSFER_FLAG);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) =
                hook.call(abi.encodeWithSelector(IERC20Hook.beforeTransfer.selector, _from, _to, _amount));
            if (!success) _revert(returndata);
        }
    }

    /// @dev Calls the beforeBurn hook, if installed.
    function _beforeBurn(address _from, uint256 _amount, bytes memory _encodedBeforeBurnArgs) internal virtual {
        address hook = getHookImplementation(BEFORE_BURN_FLAG);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) = hook.call{value: msg.value}(
                abi.encodeWithSelector(IERC20Hook.beforeBurn.selector, _from, _amount, _encodedBeforeBurnArgs)
            );
            if (!success) _revert(returndata);
        }
    }

    /// @dev Calls the beforeApprove hook, if installed.
    function _beforeApprove(address _from, address _to, uint256 _amount) internal virtual {
        address hook = getHookImplementation(BEFORE_APPROVE_FLAG);

        if (hook != address(0)) {
            (bool success, bytes memory returndata) =
                hook.call(abi.encodeWithSelector(IERC20Hook.beforeApprove.selector, _from, _to, _amount));
            if (!success) _revert(returndata);
        }
    }
}

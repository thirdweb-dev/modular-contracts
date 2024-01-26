// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import { IERC7572 } from "../interface/eip/IERC7572.sol";
import { IERC20CoreCustomErrors } from "../interface/erc20/IERC20CoreCustomErrors.sol";
import { IERC20Hook } from "../interface/erc20/IERC20Hook.sol";
import { IERC20HookInstaller } from "../interface/erc20/IERC20HookInstaller.sol";
import { ERC20Initializable } from "./ERC20Initializable.sol";
import { HookInstaller } from "../extension/HookInstaller.sol";
import { Initializable } from "../extension/Initializable.sol";
import { Permission } from "../extension/Permission.sol";

contract ERC20Core is
  Initializable,
  ERC20Initializable,
  HookInstaller,
  Permission,
  IERC20HookInstaller,
  IERC20CoreCustomErrors,
  IERC7572
{
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

  bytes32 private constant PERMIT_TYPEHASH =
    keccak256(
      "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

  /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

  /// @notice The contract URI of the contract.
  string private _contractURI;

  /// @notice nonces for EIP-2612 Permit functionality.
  mapping(address => uint256) private _nonces;

  /*//////////////////////////////////////////////////////////////
                    CONSTRUCTOR + INITIALIZE
    //////////////////////////////////////////////////////////////*/

  constructor() {
    _disableInitializers();
  }

  /**
   *  @notice Initializes the ERC-20 Core contract.
   *  @param _defaultAdmin The default admin for the contract.
   *  @param _name The name of the token collection.
   *  @param _symbol The symbol of the token collection.
   *  @param _uri Contract URI.
   */
  function initialize(
    address _defaultAdmin,
    string memory _name,
    string memory _symbol,
    string memory _uri
  ) external initializer {
    _setupContractURI(_uri);
    __ERC20_init(_name, _symbol);
    _setupRole(_defaultAdmin, ADMIN_ROLE_BITS);
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
    return _contractURI;
  }

  /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  /**
   *  @notice Sets the contract URI of the contract.
   *  @dev Only callable by contract admin.
   *  @param _uri The contract URI to set.
   */
  function setContractURI(
    string memory _uri
  ) external onlyAuthorized(ADMIN_ROLE_BITS) {
    _setupContractURI(_uri);
  }

  /**
   *  @notice Burns tokens.
   *  @dev Calls the beforeBurn hook. Skips calling the hook if it doesn't exist.
   *  @param _amount The amount of tokens to burn.
   */
  function burn(uint256 _amount) external {
    _beforeBurn(msg.sender, _amount);
    _burn(msg.sender, _amount);
  }

  /**
   *  @notice Mints tokens. Calls the beforeMint hook.
   *  @dev Reverts if beforeMint hook is absent or unsuccessful.
   *  @param _to The address to mint the tokens to.
   *  @param _amount The amount of tokens to mint.
   *  @param _encodedBeforeMintArgs ABI encoded arguments to pass to the beforeMint hook.
   */
  function mint(
    address _to,
    uint256 _amount,
    bytes memory _encodedBeforeMintArgs
  ) external payable {
    IERC20Hook.MintParams memory mintParams = _beforeMint(
      _to,
      _amount,
      _encodedBeforeMintArgs
    );
    _mint(_to, mintParams.quantityToMint);
  }

  /**
   *  @notice Transfers ownership of tokens from one address to another.
   *  @dev Overriden to call the beforeTransfer hook. Skips calling the hook if it doesn't exist.
   *  @param _from The address to transfer from
   *  @param _to The address to transfer to
   *  @param _amount The amount of tokens to transfer
   */
  function transferFrom(
    address _from,
    address _to,
    uint256 _amount
  ) public override returns (bool) {
    _beforeTransfer(_from, _to, _amount);
    return super.transferFrom(_from, _to, _amount);
  }

  /**
   *  @notice Approves an address to transfer tokens. Reverts if caller is not owner or approved operator.
   *  @dev Overriden to call the beforeApprove hook. Skips calling the hook if it doesn't exist.
   *  @param _spender The address to approve
   *  @param _amount The amount of tokens to approve
   */
  function approve(
    address _spender,
    uint256 _amount
  ) public override returns (bool) {
    _beforeApprove(msg.sender, _spender, _amount);
    return super.approve(msg.sender, _spender, _amount);
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
   *  @param owner The account approving the tokens
   *  @param spender The address to approve
   *  @param value Amount of tokens to approve
   */
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public {
    if (deadline < block.timestamp) {
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
            keccak256(
              abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                _nonces[owner]++,
                deadline
              )
            )
          )
        ),
        v,
        r,
        s
      );

      if (recoveredAddress == address(0) || recoveredAddress != owner) {
        revert ERC20PermitInvalidSigner();
      }

      super._approve(owner, spender, value);
    }
  }

  /**
   * @notice Returns the current nonce for token owner.
   *
   * See https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
   * section].
   */
  function nonces(address owner) external view returns (uint256) {
    return _nonces[owner];
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

  function computeDomainSeparator() internal view returns (bytes32) {
    return
      keccak256(
        abi.encode(
          keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
          ),
          keccak256(bytes(name)),
          keccak256("1"),
          block.chainid,
          address(this)
        )
      );
  }

  /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  /// @dev Sets contract URI
  function _setupContractURI(string memory _uri) internal {
    _contractURI = _uri;
    emit ContractURIUpdated();
  }

  /// @dev Returns whether the given caller can update hooks.
  function _canUpdateHooks(
    address _caller
  ) internal view override returns (bool) {
    return hasRole(_caller, ADMIN_ROLE_BITS);
  }

  /// @dev Should return the max flag that represents a hook.
  function _maxHookFlag() internal pure override returns (uint256) {
    return BEFORE_APPROVE_FLAG;
  }

  /*//////////////////////////////////////////////////////////////
                        HOOKS INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  /// @dev Calls the beforeMint hook.
  function _beforeMint(
    address _to,
    uint256 _amount,
    bytes memory _data
  ) internal virtual returns (IERC20Hook.MintParams memory mintParams) {
    address hook = getHookImplementation(BEFORE_MINT_FLAG);

    if (hook != address(0)) {
      mintParams = IERC20Hook(hook).beforeMint{ value: msg.value }(
        _to,
        _amount,
        _data
      );
    } else {
      revert ERC20CoreMintingDisabled();
    }
  }

  /// @dev Calls the beforeTransfer hook, if installed.
  function _beforeTransfer(
    address _from,
    address _to,
    uint256 _amount
  ) internal virtual {
    address hook = getHookImplementation(BEFORE_TRANSFER_FLAG);

    if (hook != address(0)) {
      IERC20Hook(hook).beforeTransfer(_from, _to, _amount);
    }
  }

  /// @dev Calls the beforeBurn hook, if installed.
  function _beforeBurn(address _from, uint256 _amount) internal virtual {
    address hook = getHookImplementation(BEFORE_BURN_FLAG);

    if (hook != address(0)) {
      IERC20Hook(hook).beforeBurn(_from, _amount);
    }
  }

  /// @dev Calls the beforeApprove hook, if installed.
  function _beforeApprove(
    address _from,
    address _to,
    uint256 _amount
  ) internal virtual {
    address hook = getHookImplementation(BEFORE_APPROVE_FLAG);

    if (hook != address(0)) {
      IERC20Hook(hook).beforeApprove(_from, _to, _amount);
    }
  }
}

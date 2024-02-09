// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC7572} from "../../interface/eip/IERC7572.sol";
import {IERC20CoreCustomErrors} from "../../interface/errors/IERC20CoreCustomErrors.sol";
import {IERC20Extension} from "../../interface/extension/IERC20Extension.sol";
import {IERC20ExtensionInstaller} from "../../interface/extension/IERC20ExtensionInstaller.sol";
import {IInitCall} from "../../interface/common/IInitCall.sol";
import {ERC20Initializable} from "./ERC20Initializable.sol";
import {IExtension, ExtensionInstaller} from "../../extension/ExtensionInstaller.sol";
import {Initializable} from "../../common/Initializable.sol";
import {Permission} from "../../common/Permission.sol";

import {ERC20CoreStorage} from "../../storage/core/ERC20CoreStorage.sol";

contract ERC20Core is
    Initializable,
    ERC20Initializable,
    ExtensionInstaller,
    Permission,
    IInitCall,
    IERC20ExtensionInstaller,
    IERC20CoreCustomErrors,
    IERC7572
{
    /*//////////////////////////////////////////////////////////////
                                  CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Bits representing the before mint extension.
    uint256 public constant BEFORE_MINT_FLAG = 2 ** 1;

    /// @notice Bits representing the before transfer extension.
    uint256 public constant BEFORE_TRANSFER_FLAG = 2 ** 2;

    /// @notice Bits representing the before burn extension.
    uint256 public constant BEFORE_BURN_FLAG = 2 ** 3;

    /// @notice Bits representing the before approve extension.
    uint256 public constant BEFORE_APPROVE_FLAG = 2 ** 4;

    /// @notice The EIP-2612 permit typehash.
    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /*//////////////////////////////////////////////////////////////
                      CONSTRUCTOR + INITIALIZE
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    /**
     *  @notice Initializes the ERC-20 Core contract.
     *  @param _extensions The extensions to install.
     *  @param _defaultAdmin The default admin for the contract.
     *  @param _name The name of the token collection.
     *  @param _symbol The symbol of the token collection.
     *  @param _uri Contract URI.
     */
    function initialize(
        InitCall calldata _initCall,
        address[] memory _extensions,
        address _defaultAdmin,
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) external initializer {
        _setupContractURI(_uri);
        __ERC20_init(_name, _symbol);
        _setupRole(_defaultAdmin, ADMIN_ROLE_BITS);

        uint256 len = _extensions.length;
        for (uint256 i = 0; i < len; i++) {
            _installExtension(IExtension(_extensions[i]));
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

    /// @notice Returns all of the contract's extensions and their implementations.
    function getAllExtensions() external view returns (ERC20Extensions memory extensions) {
        extensions = ERC20Extensions({
            beforeMint: getExtensionImplementation(BEFORE_MINT_FLAG),
            beforeTransfer: getExtensionImplementation(BEFORE_TRANSFER_FLAG),
            beforeBurn: getExtensionImplementation(BEFORE_BURN_FLAG),
            beforeApprove: getExtensionImplementation(BEFORE_APPROVE_FLAG)
        });
    }

    /**
     *  @notice Returns the contract URI of the contract.
     *  @return uri The contract URI of the contract.
     */
    function contractURI() external view override returns (string memory) {
        return ERC20CoreStorage.data().contractURI;
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
     *  @notice Burns tokens.
     *  @dev Calls the beforeBurn extension. Skips calling the extension if it doesn't exist.
     *  @param _amount The amount of tokens to burn.
     *  @param _encodedBeforeBurnArgs ABI encoded arguments to pass to the beforeBurn extension.
     */
    function burn(uint256 _amount, bytes memory _encodedBeforeBurnArgs) external {
        _beforeBurn(msg.sender, _amount, _encodedBeforeBurnArgs);
        _burn(msg.sender, _amount);
    }

    /**
     *  @notice Mints tokens. Calls the beforeMint extension.
     *  @dev Reverts if beforeMint extension is absent or unsuccessful.
     *  @param _to The address to mint the tokens to.
     *  @param _amount The amount of tokens to mint.
     *  @param _encodedBeforeMintArgs ABI encoded arguments to pass to the beforeMint extension.
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
                        keccak256(
                            abi.encode(
                                PERMIT_TYPEHASH,
                                _owner,
                                _spender,
                                _value,
                                ERC20CoreStorage.data().nonces[_owner]++,
                                _deadline
                            )
                        )
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
        return ERC20CoreStorage.data().nonces[owner];
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
        ERC20CoreStorage.data().contractURI = _uri;
        emit ContractURIUpdated();
    }

    /// @dev Returns whether the given caller can update extensions.
    function _canUpdateExtensions(address _caller) internal view override returns (bool) {
        return hasRole(_caller, ADMIN_ROLE_BITS);
    }

    /// @dev Should return the max flag that represents a extension.
    function _maxExtensionFlag() internal pure override returns (uint256) {
        return BEFORE_APPROVE_FLAG;
    }

    /*//////////////////////////////////////////////////////////////
                          EXTENSIONS INTERNAL FUNCTIONS
      //////////////////////////////////////////////////////////////*/

    /// @dev Calls the beforeMint extension.
    function _beforeMint(address _to, uint256 _amount, bytes memory _data)
        internal
        virtual
        returns (uint256 quantityToMint)
    {
        address extension = getExtensionImplementation(BEFORE_MINT_FLAG);

        if (extension != address(0)) {
            quantityToMint = IERC20Extension(extension).beforeMint{value: msg.value}(_to, _amount, _data);
        } else {
            revert ERC20CoreMintingDisabled();
        }
    }

    /// @dev Calls the beforeTransfer extension, if installed.
    function _beforeTransfer(address _from, address _to, uint256 _amount) internal virtual {
        address extension = getExtensionImplementation(BEFORE_TRANSFER_FLAG);

        if (extension != address(0)) {
            IERC20Extension(extension).beforeTransfer(_from, _to, _amount);
        }
    }

    /// @dev Calls the beforeBurn extension, if installed.
    function _beforeBurn(address _from, uint256 _amount, bytes memory _encodedBeforeBurnArgs) internal virtual {
        address extension = getExtensionImplementation(BEFORE_BURN_FLAG);

        if (extension != address(0)) {
            IERC20Extension(extension).beforeBurn(_from, _amount, _encodedBeforeBurnArgs);
        }
    }

    /// @dev Calls the beforeApprove extension, if installed.
    function _beforeApprove(address _from, address _to, uint256 _amount) internal virtual {
        address extension = getExtensionImplementation(BEFORE_APPROVE_FLAG);

        if (extension != address(0)) {
            IERC20Extension(extension).beforeApprove(_from, _to, _amount);
        }
    }
}

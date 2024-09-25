// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {SplitWalletCore} from "../core/SplitWalletCore.sol";

import {IERC20} from "../interface/IERC20.sol";
import {Cast} from "../libraries/Cast.sol";
import {ShortString, ShortStrings} from "../libraries/ShortString.sol";
import {Split} from "../libraries/Split.sol";
import {SplitWalletModule} from "../module/SplitWalletModule.sol";

import {AfterWithdrawCallback} from "../callback/AfterWithdrawCallback.sol";
import {BeforeDistributeCallback} from "../callback/BeforeDistributeCallback.sol";

import {ERC6909} from "@solady/tokens/ERC6909.sol";
import {Initializable} from "@solady/utils/Initializable.sol";
import {LibClone} from "@solady/utils/LibClone.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";

import {Core} from "../Core.sol";

contract SplitFeesCore is
    Core,
    Multicallable,
    ERC6909,
    Initializable,
    BeforeDistributeCallback,
    AfterWithdrawCallback
{

    using ShortStrings for string;
    using ShortStrings for ShortString;
    using Cast for uint256;
    using Cast for address;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice prefix for metadata name.
    string private constant METADATA_PREFIX_NAME = "Splits Wrapped ";

    /// @notice prefix for metadata symbol.
    string private constant METADATA_PREFIX_SYMBOL = "splits";

    /// @notice address of the native token, inline with ERC 7528.
    address public constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice uint256 representation of the native token.
    uint256 public constant NATIVE_TOKEN_ID = uint256(uint160(NATIVE_TOKEN_ADDRESS));

    /// @notice metadata name of the native token.
    ShortString private immutable NATIVE_TOKEN_NAME;

    /// @notice metadata symbol of the native token.
    ShortString private immutable NATIVE_TOKEN_SYMBOL;

    address public splitWalletImplementation;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    function _initialize(address _owner) external initializer {
        _initializeOwner(_owner);

        SplitWalletModule splitWalletModule = new SplitWalletModule();

        address[] memory modules = new address[](1);
        bytes[] memory moduleInstallData = new bytes[](1);
        modules[0] = address(splitWalletModule);

        SplitWalletCore splitWalletCore = new SplitWalletCore(_owner, modules, moduleInstallData);
        splitWalletImplementation = address(splitWalletCore);
    }

    function getSupportedCallbackFunctions()
        public
        pure
        override
        returns (SupportedCallbackFunction[] memory supportedCallbackFunctions)
    {
        supportedCallbackFunctions = new SupportedCallbackFunction[](2);

        supportedCallbackFunctions[0] = SupportedCallbackFunction({
            selector: BeforeDistributeCallback.beforeDistribute.selector,
            mode: CallbackMode.REQUIRED
        });
        supportedCallbackFunctions[1] = SupportedCallbackFunction({
            selector: AfterWithdrawCallback.afterWithdraw.selector,
            mode: CallbackMode.REQUIRED
        });
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC6909, Core) returns (bool) {
        return interfaceId == 0x0f632fb3 || super.supportsInterface(interfaceId);
    }

    function distribute(address _splitWallet, address _token) external {
        (uint256 amountToSplit, Split memory _split) = _beforeDistribute(_splitWallet, _token);

        uint256 length = _split.recipients.length;
        for (uint256 i = 0; i < length; i++) {
            uint256 amountToSend = (amountToSplit * _split.allocations[i]) / _split.totalAllocation;

            _mint(_split.recipients[i], _token.toUint256(), amountToSend);
        }
    }

    function withdraw(address account, address _token) external {
        uint256 amountToWithdraw = balanceOf(account, _token.toUint256());
        _burn(account, _token.toUint256(), amountToWithdraw);
        _afterWithdraw(amountToWithdraw, account, _token);
    }

    /**
     * @notice Name of a given token.
     * @param id The id of the token.
     * @return The name of the token.
     */
    function name(uint256 id) public view override returns (string memory) {
        if (id == NATIVE_TOKEN_ID) {
            return NATIVE_TOKEN_NAME.toString();
        }
        return string.concat(METADATA_PREFIX_NAME, IERC20(id.toAddress()).name());
    }

    /**
     * @notice Symbol of a given token.
     * @param id The id of the token.
     * @return The symbol of the token.
     */
    function symbol(uint256 id) public view override returns (string memory) {
        if (id == NATIVE_TOKEN_ID) {
            return NATIVE_TOKEN_SYMBOL.toString();
        }
        return string.concat(METADATA_PREFIX_SYMBOL, IERC20(id.toAddress()).symbol());
    }

    /// @dev Returns the Uniform Resource Identifier (URI) for token `id`.
    function tokenURI(uint256 id) public view override returns (string memory) {
        return "";
    }

    /// @dev Fetches token URI from the token metadata hook.
    function _beforeDistribute(address _splitWallet, address _token)
        internal
        returns (uint256 amountToSplit, Split memory _split)
    {
        (, bytes memory returndata) = _executeCallbackFunctionView(
            BeforeDistributeCallback.beforeDistribute.selector,
            abi.encodeCall(BeforeDistributeCallback.beforeDistribute, (_splitWallet, _token))
        );
        (amountToSplit, _split) = abi.decode(returndata, (uint256, Split));
    }

    /// @dev Fetches token URI from the token metadata hook.
    function _afterWithdraw(uint256 amountToWithdraw, address account, address _token) internal {
        _executeCallbackFunctionView(
            AfterWithdrawCallback.afterWithdraw.selector,
            abi.encodeCall(AfterWithdrawCallback.afterWithdraw, (amountToWithdraw, account, _token))
        );
    }

}

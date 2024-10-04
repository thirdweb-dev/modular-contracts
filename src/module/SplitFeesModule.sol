pragma solidity ^0.8.20;

import {Split} from "../libraries/Split.sol";

import {SplitFeesCore} from "../core/SplitFeesCore.sol";

import {IERC20} from "../interface/IERC20.sol";
// import {ISplitWallet} from "../interface/ISplitWallet.sol";
import {SplitWalletModule} from "../module/SplitWalletModule.sol";

import {AfterWithdrawCallback} from "../callback/AfterWithdrawCallback.sol";
import {BeforeDistributeCallback} from "../callback/BeforeDistributeCallback.sol";

import {LibClone} from "@solady/utils/LibClone.sol";

import {Module} from "../Module.sol";

library SplitFeesStorage {

    /// @custom:storage-location erc7201:split.fees
    bytes32 public constant SPLIT_FEES_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("split.fees")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        mapping(address => Split) splits;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = SPLIT_FEES_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }

}

contract SplitFeesModule is Module, BeforeDistributeCallback, AfterWithdrawCallback {

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice address of the native token, inline with ERC 7528.
    address public constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event SplitCreated(address indexed splitWallet, address[] recipients, uint256[] allocations, address controller);
    event SplitsUpdated(address indexed splitWallet, address[] recipients, uint256[] allocations, address controller);
    event ControllerUpdated(address indexed splitWallet, address controller);
    event SplitsDistributed(address indexed splitWallet, address token, uint256 amount);
    event SplitsWithdrawn(address indexed recipient, address token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error SplitFeesTooFewRecipients();
    error SplitFeesEmptyRecipientsOrAllocations();
    error SplitFeesLengthMismatch();
    error SplitFeesNotController();
    error SplitFeesAmountMismatch();
    error SplitFeesNothingToWithdraw();
    error SplitFeesWithdrawFailed();

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyController(address _splitWallet) {
        if (_splitFeesStorage().splits[_splitWallet].controller != msg.sender) {
            revert SplitFeesNotController();
        }
        _;
    }

    modifier validateSplits(address[] memory _recipients, uint256[] memory _allocations, address _controller) {
        if (_recipients.length < 2) {
            revert SplitFeesTooFewRecipients();
        }
        if (_recipients.length == 0 || _allocations.length == 0) {
            revert SplitFeesEmptyRecipientsOrAllocations();
        }
        if (_recipients.length != _allocations.length) {
            revert SplitFeesLengthMismatch();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            MODULE CONFIG
    //////////////////////////////////////////////////////////////*/

    function getModuleConfig() external pure virtual override returns (ModuleConfig memory) {
        ModuleConfig memory config;
        config.callbackFunctions = new CallbackFunction[](2);
        config.callbackFunctions[0] = CallbackFunction(this.beforeDistribute.selector);
        config.callbackFunctions[1] = CallbackFunction(this.afterWithdraw.selector);

        config.fallbackFunctions = new FallbackFunction[](3);
        config.fallbackFunctions[0] = FallbackFunction({selector: this.createSplit.selector, permissionBits: 0});
        config.fallbackFunctions[1] = FallbackFunction({selector: this.updateSplit.selector, permissionBits: 0});
        config.fallbackFunctions[2] = FallbackFunction({selector: this.getSplit.selector, permissionBits: 0});

        return config;
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function beforeDistribute(address _splitWallet, address _token) external override returns (uint256, Split memory) {
        Split memory _split = _splitFeesStorage().splits[_splitWallet];
        uint256 amountToSplit;

        if (_token == NATIVE_TOKEN_ADDRESS) {
            amountToSplit = _splitWallet.balance;
            SplitWalletModule(_splitWallet).transferETH(amountToSplit);
        } else {
            amountToSplit = IERC20(_token).balanceOf(_splitWallet);
            SplitWalletModule(_splitWallet).transferERC20(_token, amountToSplit);
        }

        emit SplitsDistributed(_splitWallet, _token, amountToSplit);

        return (amountToSplit, _split);
    }

    function afterWithdraw(uint256 amountToWithdraw, address account, address _token) external override {
        if (amountToWithdraw == 0) {
            revert SplitFeesNothingToWithdraw();
        }

        if (_token == NATIVE_TOKEN_ADDRESS) {
            (bool success,) = payable(account).call{value: amountToWithdraw}("");
            if (!success) {
                revert SplitFeesWithdrawFailed();
            }
        } else {
            IERC20(_token).transfer(account, amountToWithdraw);
        }

        emit SplitsWithdrawn(account, _token, amountToWithdraw);
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Core contract calls this in constructor
    function createSplit(address[] memory _recipients, uint256[] memory _allocations, address _controller)
        external
        validateSplits(_recipients, _allocations, _controller)
    {
        Split memory _split = _setSplits(_recipients, _allocations, _controller);
        address splitWalletImplementation = SplitFeesCore(payable(address(this))).splitWalletImplementation();

        address splitWallet = LibClone.clone(splitWalletImplementation);
        _splitFeesStorage().splits[splitWallet] = _split;

        emit SplitCreated(splitWallet, _recipients, _allocations, _controller);
    }

    function updateSplit(
        address _splitWallet,
        address[] memory _recipients,
        uint256[] memory _allocations,
        address _controller
    ) external onlyController(_splitWallet) validateSplits(_recipients, _allocations, _controller) {
        Split memory _split = _setSplits(_recipients, _allocations, _controller);
        _splitFeesStorage().splits[_splitWallet] = _split;

        emit SplitsUpdated(_splitWallet, _recipients, _allocations, _controller);
    }

    function getSplit(address _splitWallet) external view returns (Split memory) {
        return _splitFeesStorage().splits[_splitWallet];
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setSplits(address[] memory _recipients, uint256[] memory _allocations, address _controller)
        internal
        pure
        returns (Split memory)
    {
        Split memory _split;
        uint256 _totalAllocation;
        _split.recipients = _recipients;
        _split.allocations = _allocations;
        _split.totalAllocation = _totalAllocation;
        _split.controller = _controller;

        uint256 length = _recipients.length;
        for (uint256 i = 0; i < length; i++) {
            _totalAllocation += _allocations[i];
        }

        return _split;
    }

    function _splitFeesStorage() internal pure returns (SplitFeesStorage.Data storage) {
        return SplitFeesStorage.data();
    }

}

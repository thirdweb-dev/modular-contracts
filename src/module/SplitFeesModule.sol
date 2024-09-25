pragma solidity ^0.8.20;

import {Split} from "../libraries/Split.sol";

import {SplitFeesCore} from "../core/SplitFeesCore.sol";
import {IERC20} from "./interface/IERC20.sol";

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

contract SplitFeesModule {

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event SplitCreated(address indexed owner, address[] recipients, uint256[] allocations, address controller);
    event SplitsUpdated(address indexed owner, address[] recipients, uint256[] allocations, address controller);
    event ControllerUpdated(address indexed owner, address controller);
    event SplitsDistributed(address indexed reciever, address token, uint256 amount);
    event SplitsWithdrawn(address indexed owner, address token, uint256 amount);

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
        if (splits[_splitWallet].controller != msg.sender) {
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
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Core contract calls this in constructor
    function createSplit(address[] memory _recipients, uint256[] memory _allocations, address _controller)
        external
        validateSplits(_recipients, _allocations, _controller)
    {
        Split memory _split = _setSplits(_split, _recipients, _allocations, _controller);
        address splitWalletImplementation = SplitFeesCore(address(this)).splitWalletImplementation();

        address splitWallet = LibClone.clone(_splitFeesStorage().splitWalletImplementation);
        splits[splitWallet] = _split;

        emit SplitCreated(splitWallet, _recipients, _allocations, _controller);
    }

    function updateSplit(
        address _splitWallet,
        address[] memory _recipients,
        uint256[] memory _allocations,
        address _controller
    ) external onlyController(_splitWallet) validateSplits(_recipients, _allocations, _controller) {
        Split memory _split = _setSplits(_split, _recipients, _allocations, _controller);
        splits[_splitWallet] = _split;

        emit SplitsUpdated(_splitWallet, _recipients, _allocations, _controller);
    }

    function beforeDistribute(address _splitWallet, address _token) external returns (uint256, Split memory) {
        Split memory _split = splits[_splitWallet];
        uint256 amountToSplit;

        if (_token == NATIVE_TOKEN_ADDRESS) {
            amountToSplit = _splitWallet.balance;
            SplitWallet(_splitWallet).transferETH(amountToSplit);
        } else {
            amountToSplit = IERC20(_token).balanceOf(_splitWallet);
            SplitWallet(_splitWallet).transferERC20(_token, amountToSplit);
        }

        emit SplitsDistributed(_splitWallet, _token, amountToSplit);

        return (amountToSplit, _split);
    }

    function afterWithdraw(uint256 amountToWithdraw, address account, address _token) external {
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

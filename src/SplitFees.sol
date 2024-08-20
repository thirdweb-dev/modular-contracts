pragma solidity ^0.8.20;

import {IERC20} from "./interface/IERC20.sol";
import {Cast} from "./libraries/Cast.sol";
import {ShortString, ShortStrings} from "./libraries/ShortString.sol";
import {Ownable} from "@solady/auth/Ownable.sol";
import {ERC6909} from "@solady/tokens/ERC6909.sol";

contract SplitFees is Ownable, ERC6909 {

    using ShortStrings for string;
    using ShortStrings for ShortString;
    using Cast for uint256;
    using Cast for address;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/
    event SplitCreated(address indexed owner, address[] recipients, uint256[] allocations, address controller);
    event SplitsUpdated(address indexed owner, address[] recipients, uint256[] allocations, address controller);
    event SplitsDistributed(address indexed reciever, address token, uint256 amount);
    event SplitsWithdrawn(address indexed owner, address token, uint256 amount);
    event ControllerUpdated(address indexed owner, address controller);

    /*//////////////////////////////////////////////////////////////
                            STRUCTS & ENUMS
    //////////////////////////////////////////////////////////////*/

    struct Split {
        address controller;
        address[] recipients;
        uint256[] allocations;
        uint256 totalAllocation;
    }

    mapping(address => Split) public splits;

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
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory _NATIVE_TOKEN_NAME, string memory _NATIVE_TOKEN_SYMBOL, address _owner) {
        _initializeOwner(_owner);

        NATIVE_TOKEN_NAME = _NATIVE_TOKEN_NAME.toShortString();
        NATIVE_TOKEN_SYMBOL = _NATIVE_TOKEN_SYMBOL.toShortString();
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyController(address _owner) {
        if (splits[_owner].controller != msg.sender) {
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
        Split memory _split;
        _setSplits(_split, _recipients, _allocations, _controller);
        splits[msg.sender] = _split;

        emit SplitCreated(msg.sender, _recipients, _allocations, _controller);
    }

    function updateSplit(
        address _owner,
        address[] memory _recipients,
        uint256[] memory _allocations,
        address _controller
    ) external onlyController(_owner) validateSplits(_recipients, _allocations, _controller) {
        Split memory _split = splits[_owner];
        _setSplits(_split, _recipients, _allocations, _controller);
        splits[_owner] = _split;

        emit SplitsUpdated(_owner, _recipients, _allocations, _controller);
    }

    function distribute(address _owner, address _token) external {
        Split memory _split = splits[_owner];
        uint256 amountToSplit = balanceOf(_owner, _token.toUint256());

        _burn(_owner, _token.toUint256(), amountToSplit);

        uint256 length = _split.recipients.length;
        for (uint256 i = 0; i < length; i++) {
            uint256 amountToSend = (amountToSplit * _split.allocations[i]) / _split.totalAllocation;

            _mint(_split.recipients[i], _token.toUint256(), amountToSend);
        }

        emit SplitsDistributed(_owner, _token, amountToSplit);
    }

    function withdraw(address _token) external {
        uint256 amountToWithdraw = balanceOf(msg.sender, _token.toUint256());
        if (amountToWithdraw == 0) {
            revert SplitFeesNothingToWithdraw();
        }

        _burn(msg.sender, _token.toUint256(), amountToWithdraw);

        if (_token == NATIVE_TOKEN_ADDRESS) {
            (bool success,) = payable(msg.sender).call{value: amountToWithdraw}("");
            if (!success) {
                revert SplitFeesWithdrawFailed();
            }
        } else {
            IERC20(_token).transfer(msg.sender, amountToWithdraw);
        }

        emit SplitsWithdrawn(msg.sender, _token, amountToWithdraw);
    }

    function deposit(address _receiver, address _token, uint256 _amount) external payable {
        if (_token == NATIVE_TOKEN_ADDRESS && msg.value != _amount) {
            revert SplitFeesAmountMismatch();
        } else {
            IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        }

        _mint(_receiver, _token.toUint256(), _amount);

        emit SplitsDistributed(_receiver, _token, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _setSplits(
        Split memory _split,
        address[] memory _recipients,
        uint256[] memory _allocations,
        address _controller
    ) internal pure {
        uint256 _totalAllocation;
        _split.recipients = _recipients;
        _split.allocations = _allocations;
        _split.totalAllocation = _totalAllocation;
        _split.controller = _controller;

        uint256 length = _recipients.length;
        for (uint256 i = 0; i < length; i++) {
            _totalAllocation += _allocations[i];
        }
    }

}

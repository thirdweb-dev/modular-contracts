pragma solidity ^0.8.20;

import {Ownable} from "@solady/auth/Ownable.sol";
import {ERC6909} from "@solady/tokens/ERC6909.sol";
import {ShortString, ShortStrings} from "./libraries/ShortString.sol";
import {IERC20} from "./interface/IERC20.sol";

contract SplitFees is Ownable, ERC6909 {
    using ShortStrings for string;
    using ShortStrings for ShortString;

    /*//////////////////////////////////////////////////////////////
                            STRUCTS & ENUMS
    //////////////////////////////////////////////////////////////*/

    address[] private recipients;
    mapping(address => uint256) private allocations;
    uint256 private totalAllocation;

    /// @notice prefix for metadata name.
    string private constant METADATA_PREFIX_NAME = "Splits Wrapped ";

    /// @notice prefix for metadata symbol.
    string private constant METADATA_PREFIX_SYMBOL = "splits";

    /// @notice address of the native token, inline with ERC 7528.
    address public constant NATIVE_TOKEN_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice uint256 representation of the native token.
    uint256 public constant NATIVE_TOKEN_ID =
        uint256(uint160(NATIVE_TOKEN_ADDRESS));

    /// @notice metadata name of the native token.
    ShortString private immutable NATIVE_TOKEN_NAME;

    /// @notice metadata symbol of the native token.
    ShortString private immutable NATIVE_TOKEN_SYMBOL;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error SplitFeesEmptyRecipientsOrAllocations();
    error SplitFeesLengthMismatch();

    constructor(
        address[] memory _recipients,
        uint256[] memory _allocations,
        string memory _NATIVE_TOKEN_NAME,
        string memory _NATIVE_TOKEN_SYMBOL,
        address _owner
    ) {
        _validateSplits(_recipients, _allocations);
        _setSplits(_recipients, _allocations);
        _initializeOwner(_owner);

        NATIVE_TOKEN_NAME = _NATIVE_TOKEN_NAME.toShortString();
        NATIVE_TOKEN_SYMBOL = _NATIVE_TOKEN_SYMBOL.toShortString();
    }

    function setSplits(
        address[] memory _recipients,
        uint256[] memory _allocations
    ) external onlyOwner {
        _validateSplits(_recipients, _allocations);
        _setSplits(_recipients, _allocations);
    }

    function distribute(address _token) external {
        if (_token == NATIVE_TOKEN_ADDRESS) {
            uint256 amountToSplit = address(this).balance;
            uint256 length = recipients.length;

            for (uint256 i = 0; i < length; i++) {
                uint256 amountToSend = (amountToSplit *
                    allocations[recipients[i]]) / totalAllocation;
            }
        } else {}
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
        return
            string.concat(
                METADATA_PREFIX_NAME,
                IERC20(address(uint160(id))).name()
            );
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
        return
            string.concat(
                METADATA_PREFIX_SYMBOL,
                IERC20(address(uint160(id))).symbol()
            );
    }

    /// @dev Returns the Uniform Resource Identifier (URI) for token `id`.
    function tokenURI(uint256 id) public view override returns (string memory) {
        return "";
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _validateSplits(
        address[] memory _recipients,
        uint256[] memory _allocations
    ) internal pure {
        if (_recipients.length == 0 || _allocations.length == 0) {
            revert SplitFeesEmptyRecipientsOrAllocations();
        }
        if (_recipients.length != _allocations.length) {
            revert SplitFeesLengthMismatch();
        }
    }

    function _setSplits(
        address[] memory _recipients,
        uint256[] memory _allocations
    ) internal {
        uint256 _totalAllocation;
        uint256 length = _recipients.length;

        for (uint256 i = 0; i < length; i++) {
            recipients.push(_recipients[i]);
            allocations[_recipients[i]] = _allocations[i];
            _totalAllocation += _allocations[i];
        }
        totalAllocation = _totalAllocation;
    }
}

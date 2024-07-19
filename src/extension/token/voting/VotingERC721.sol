// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {Historical} from "./Historical.sol";
import {ModularExtension} from "../../../ModularExtension.sol";
import {IERC721A, ERC721A, ERC721AQueryable} from "@erc721a/extensions/ERC721AQueryable.sol";
import {SafeCastLib} from "@solady/utils/SafeCastLib.sol";
import {EIP712} from "@solady/utils/EIP712.sol";
import {ECDSA} from "@solady/utils/ECDSA.sol";

library VotingStorage {
    /// @custom:storage-location erc7201:token.voting
    bytes32 public constant VOTING_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.voting")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        mapping(address account => address) delegatedTo;
        mapping(address delegatee => Historical.Timeline) delegatedVotes;
        mapping(address account => uint256) nonces;
        Historical.Timeline totalVotes;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = VOTING_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract VotingERC721 is ERC721AQueryable, EIP712, ModularExtension {
    using Historical for Historical.Timeline;

    bytes32 private constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");


    /*//////////////////////////////////////////////////////////////
                            STRUCTS & ENUMS
    //////////////////////////////////////////////////////////////*/

    struct Timeline {
        Checkpoint[] checkpoints;
    }

    struct Checkpoint {
        uint48 key;
        uint208 value;
    }

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice The clock was incorrectly modified.
    error ERC6372InconsistentClock();

    /// @notice Lookup to future votes is not available.
    error InvalidFutureLookup(uint256 timepoint, uint48 clock);

    /// @notice Lookup to future votes is not available.
    error InvalidNonce(uint256 nonce);
    
    /// @notice The signature used has expired.
    error VotesExpiredSignature(uint256 expiry);

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Emitted when an account changes their delegate.
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    
    /// @notice Emitted when a token transfer or delegate change results in changes to a delegate's number of voting units.
    event DelegateVotesChanged(address indexed delegate, uint256 previousVotes, uint256 newVotes);


    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
 
    constructor() ERC721A("vote", "VOTE") {}

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    function getExtensionConfig() external pure override returns (ExtensionConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](3);
        config.fallbackFunctions = new FallbackFunction[](10);

        config.callbackFunctions[0] = CallbackFunction(this.beforeMintERC721.selector);
        config.callbackFunctions[1] = CallbackFunction(this.beforeBurnERC721.selector);
        config.callbackFunctions[2] = CallbackFunction(this.beforeTransferERC721.selector);

        config.fallbackFunctions[0] = 
            FallbackFunction({selector: this.clock.selector, permissionBits: 0});
        config.fallbackFunctions[1] =
            FallbackFunction({selector: this.CLOCK_MODE.selector, permissionBits: 0});
        config.fallbackFunctions[2] =
            FallbackFunction({selector: this.getVotes.selector, permissionBits: 0});
        config.fallbackFunctions[3] =
            FallbackFunction({selector: this.getPastVotes.selector, permissionBits: 0});
        config.fallbackFunctions[4] = 
            FallbackFunction({selector: this.getPastTotalSupply.selector, permissionBits: 0});
        config.fallbackFunctions[5] = 
            FallbackFunction({selector: this.getTotalSupply.selector, permissionBits: 0});
        config.fallbackFunctions[6] =
            FallbackFunction({selector: this.delegates.selector, permissionBits: 0});
        config.fallbackFunctions[7] =
            FallbackFunction({selector: this.delegate.selector, permissionBits: 0});
        config.fallbackFunctions[8] =
            FallbackFunction({selector: this.delegateBySig.selector, permissionBits: 0});
        config.fallbackFunctions[9] =
            FallbackFunction({selector: this.nonces.selector, permissionBits: 0});

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0x80ac58cd; // ERC721.

        config.registerInstallationCallback = false;
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for the ERC721Core.mint function.
    function beforeMintERC721(address _to, uint256 _startTokenId, uint256 _quantity, bytes memory _data)
        external
        payable
    {
        _transferVotingUnits(address(0), _to, _quantity);
    }

    /// @notice Callback function for the ERC721Core.transferFrom function.
    function beforeTransferERC721(address from, address to, uint256 tokenId)
        external
        payable
    {
        _transferVotingUnits(from, to, 1);
    }

    /// @notice Callback function for the ERC721Core.burn function.
    function beforeBurnERC721(uint256 tokenId, bytes calldata data)
        external
        payable
    {
        _transferVotingUnits(msg.sender, address(0), 1);
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Clock used for flagging checkpoints. Can be overridden to implement timestamp based
     * checkpoints (and voting), in which case {CLOCK_MODE} should be overridden as well to match.
     */
    function clock() public view virtual returns (uint48) {
        return SafeCastLib.toUint48(block.timestamp);
    }

    
    /// @notice Machine-readable description of the clock as specified in ERC-6372.
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public view virtual returns (string memory) {
        // Check that the clock was not modified
        if (clock() != SafeCastLib.toUint48(block.number)) {
            revert ERC6372InconsistentClock();
        }
        return "mode=blocknumber&from=default";
    }

    /// @notice Returns the current nonce for `account`.
    function nonces(address account) public view returns (uint256) {
        return _votingStorage().nonces[account];
    }

    /// @notice Returns the current amount of votes that `account` has.
    function getVotes(address account) public view virtual returns (uint256) {
        return _votingStorage().delegatedVotes[account].latest();
    }

    //// @notice Returns the amount of votes that `account` had at a specific moment in the past.
    function getPastVotes(address account, uint256 timepoint) public view virtual returns (uint256) {
        uint48 currentTimepoint = clock();
        if (timepoint >= currentTimepoint) {
            revert InvalidFutureLookup(timepoint, currentTimepoint);
        }
        return _votingStorage().delegatedVotes[account].lookup(SafeCastLib.toUint48(timepoint));
    }

    /**
     * @notice Returns the total supply of votes available at a specific moment in the past.
     *
     * - This represents all votes available, inlcuding votes that have not been delegated yet. This does not represent
     *   the sum of all delegated votes.
     * - `timepoint` must be in the past.
     */
    function getPastTotalSupply(uint256 timepoint) public view virtual returns (uint256) {
        uint48 currentTimepoint = clock();
        if (timepoint >= currentTimepoint) {
            revert InvalidFutureLookup(timepoint, currentTimepoint);
        }
        return _votingStorage().totalVotes.lookup(SafeCastLib.toUint48(timepoint));
    }

    /// @notice Returns the current total supply of votes.
    function getTotalSupply() external view returns (uint256) {
        return _votingStorage().totalVotes.latest();
    }

    /// @notice Returns the delegate that `account` has chosen.
    function delegates(address account) public view virtual returns (address) {
        address delegatedTo = _votingStorage().delegatedTo[account];
        return delegatedTo;
    }

    /// @notice Delegates votes from the sender to `delegatee`.
    function delegate(address delegatee) public virtual {
        address account = msg.sender;
        _delegate(account, delegatee);
    }

    /// @notice Delegates votes from signer to `delegatee`.
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        if (block.timestamp > expiry) revert VotesExpiredSignature(expiry); 
        address signer = ECDSA.recover(
            _hashTypedData(keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry))),
            v,
            r,
            s
        );
        _useNonce(signer, nonce);
        _delegate(signer, delegatee);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Delegates all of `account`'s voting units to `delegatee`.
    function _delegate(address account, address delegatee) internal virtual {
        address oldDelegate = delegates(account);
        _votingStorage().delegatedTo[account] = delegatee;

        emit DelegateChanged(account, oldDelegate, delegatee);
        _moveDelegateVotes(oldDelegate, delegatee, _getVotingUnits(account));
    }

    /**
     * @notice Transfers, mints, or burns voting units. To register a mint, `from` should be zero. To register a burn, `to`
     * should be zero. Total supply of voting units will be adjusted with mints and burns.
     */
    function _transferVotingUnits(address from, address to, uint256 amount) internal virtual {
        Historical.Timeline storage totalVotes = _votingStorage().totalVotes;
        if (from == address(0)) {
            _push(totalVotes, _add, SafeCastLib.toUint208(amount));
        }
        if (to == address(0)) {
            _push(totalVotes, _subtract, SafeCastLib.toUint208(amount));
        }
        _moveDelegateVotes(delegates(from), delegates(to), amount);
    }

    /// @notice Moves delegated votes from one delegate to another.
    function _moveDelegateVotes(address from, address to, uint256 amount) private {
        if (from != to && amount > 0) {
            mapping(address => Historical.Timeline) storage delegatedVotes = _votingStorage().delegatedVotes;
            if (from != address(0)) {
                (uint256 oldValue, uint256 newValue) = _push(
                    delegatedVotes[from],
                    _subtract,
                    SafeCastLib.toUint208(amount)
                );
                emit DelegateVotesChanged(from, oldValue, newValue);
            }
            if (to != address(0)) {
                (uint256 oldValue, uint256 newValue) = _push(
                    delegatedVotes[to],
                    _add,
                    SafeCastLib.toUint208(amount)
                );
                emit DelegateVotesChanged(to, oldValue, newValue);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            UTIL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _push(
        Historical.Timeline storage timeline,
        function(uint208, uint208) view returns (uint208) op,
        uint208 delta
    ) private returns (uint208, uint208) {
        return timeline.push(clock(), op(timeline.latest(), delta));
    }

    function _add(uint208 a, uint208 b) internal view returns (uint208) {
        return a + b;
    }

    function _subtract(uint208 a, uint208 b) internal view returns (uint208) {
        return a - b;
    }

    /// @notice Returns the balance of `account`.
    function _getVotingUnits(address account) internal view returns (uint256) {
        return balanceOf(account);
    }

    function _useNonce(address signer, uint256 nonce) internal {
        if (nonce != _votingStorage().nonces[msg.sender]) revert InvalidNonce(nonce);
        unchecked {
            _votingStorage().nonces[signer] += 1;
        }
    }

    /// @notice Returns the domain name and version for EIP712.
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "VotingERC721";
        version = "1";
    }

    function _votingStorage() internal pure returns (VotingStorage.Data storage) {
        return VotingStorage.data();
    }
}
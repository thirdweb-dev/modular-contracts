// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Initializable} from "../extension/Initializable.sol";
import {IERC20} from "../interface/erc20/IERC20.sol";
import {IERC20Metadata} from "../interface/erc20/IERC20Metadata.sol";
import {IERC20CustomErrors} from "../interface/erc20/IERC20CustomErrors.sol";

abstract contract ERC20Initializable is
    Initializable,
    IERC20,
    IERC20Metadata,
    IERC20CustomErrors
{
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The name of the token.
    string public name;

    /// @notice The symbol of the token.
    string public symbol;

    /**
     *  @notice The total circulating supply of tokens.
     */
    uint256 private _totalSupply;

    /// @notice Mapping from owner address to number of owned token.
    mapping(address => uint256) private _balanceOf;

    /// @notice Mapping from owner to spender allowance.
    mapping(address => mapping(address => uint256)) private _allowances;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract with collection name and symbol.
    function __ERC20_init(string memory _name, string memory _symbol) internal onlyInitializing {
        name = _name;
        symbol = _symbol;
        _totalSupply = 1;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function balanceOf(address _owner) public view virtual returns (uint256) {
        return _balanceOf[_owner];
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply - 1; // We initialize totalSupply as `1` in `initialize` to save on `mint` gas.
    }

    function allowance(address _owner, address _spender) public view virtual override returns (uint256) {
        return _allowances[_owner][_spender];
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function approve(address _spender, uint256 _amount) public virtual returns (bool) {
        address _owner = msg.sender;

        if (_owner == address(0)) {
            revert ERC20FromZeroAddress(msg.sender, _amount);
        }

        if (_spender == address(0)) {
            revert ERC20ToZeroAddress(_spender, _amount);
        }

        _allowances[_owner][_spender] = _amount;

        emit Approval(_owner, _spender, _amount);

        return true;
    }

    function transfer(address _to, uint256 _amount) public virtual returns (bool) {
        if(_to == address(0)) {
            revert ERC20TransferToZeroAddress();
        }

        address _owner = msg.sender;
        uint256 _balance = _balanceOf[_owner];

        if(_balance < _amount) {
            revert ERC20TransferAmountExceedsBalance(_amount, _balance);
        }

        unchecked {
            _balanceOf[_owner] = _balance - _amount;

            // Cannot overflow because the sum of all user
            // balances can't exceed the max uint256 value.
            _balanceOf[_to] += _amount;
        }

        emit Transfer(_owner, _to, _amount);

        return true;
    }

    function transferFrom(address _from, address _to, uint256 _amount) public virtual returns (bool) {
        if(_to == address(0)) {
            revert ERC20TransferToZeroAddress();
        }

        if(_from == address(0)) {
            revert ERC20TransferFromZeroAddress();
        }

        address _spender = msg.sender;
        uint256 _allowance = _allowances[_from][_spender];
        uint256 _balance = _balanceOf[_from];

        if (_allowance != type(uint256).max) {
            if(_allowance < _amount) {
                revert ERC20InsufficientAllowance(_allowance, _amount);
            }
            _allowances[_from][_spender] = _allowance - _amount;
        } 

        if(_balance < _amount) {
            revert ERC20TransferAmountExceedsBalance(_amount, _balance);
        }


        unchecked {
            _balanceOf[_from] = _balance - _amount;

            // Cannot overflow because the sum of all user
            // balances can't exceed the max uint256 value.
            _balanceOf[_to] += _amount;
        }

        emit Transfer(_from, _to, _amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _mint(address _to, uint256 _amount) internal virtual {
        if (_to == address(0)) {
            revert ERC20ToZeroAddress(_to, _amount);
        }

        _totalSupply += _amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            _balanceOf[_to] += _amount;
        }

        emit Transfer(address(0), _to, _amount);
    }

    function _burn(address _owner, uint256 _amount) internal virtual {
        if (_owner == address(0)) {
            revert ERC20FromZeroAddress(_owner, _amount);
        }

        uint256 _balance = _balanceOf[_owner];

        if(_balance < _amount) {
            revert ERC20TransferAmountExceedsBalance(_amount, _balance);
        }

        unchecked {
            _balanceOf[_owner] = _balance - _amount;

            // Cannot underflow because a user's balance
            // will never be larger than the total supply.
            _totalSupply -= _amount;
        }

        emit Transfer(_owner, address(0), _amount);
    }
}

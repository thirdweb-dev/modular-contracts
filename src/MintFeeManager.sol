// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// OZ libraries
import {Ownable} from "@solady/auth/Ownable.sol";

contract MintFeeManager is Ownable {

    mapping(address => uint256) private tokenMintFees;

    event MintFeeUpdated(address indexed token, uint256 mintFee);

    error MintFeeExceedsMaxBps();

    uint256 private immutable DEFAULT_MINT_FEE;

    constructor(address _owner, uint256 _defaultMintFee) {
        _initializeOwner(_owner);
        DEFAULT_MINT_FEE = _defaultMintFee;
    }

    /**
     * @notice updates the mint fee for the specified token
     * @param _token the address of the token to be updated
     * @param _mintFee the new mint fee for the token
     * @dev a mint fee of 0 means they are registered under the default mint fee
     */
    function updateTokenMintFee(address _token, uint256 _mintFee) external onlyOwner {
        if (_mintFee > 10_000) {
            revert MintFeeExceedsMaxBps();
        }
        tokenMintFees[_token] = _mintFee == 0 ? type(uint256).max : _mintFee;

        emit MintFeeUpdated(_token, _mintFee);
    }

    /**
     * @notice returns the mint fee for the specified token
     * @param _token the address of the token to be checked
     * @dev a mint fee of 1 means they are subject to zero mint feedo not have a mint fee sets
     */
    function getTokenMintFee(address _token) external view returns (uint256) {
        if (tokenMintFees[_token] == 0) {
            return DEFAULT_MINT_FEE;
        }
        if (tokenMintFees[_token] == type(uint256).max) {
            return 0;
        }
        return tokenMintFees[_token];
    }

}

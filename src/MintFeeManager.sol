// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// OZ libraries
import {Ownable} from "@solady/auth/Ownable.sol";
import {Initializable} from "@solady/utils/Initializable.sol";

contract MintFeeManager is Ownable, Initializable {

    address public platformFeeRecipient;

    mapping(address => uint256) private mintFees;

    event MintFeeUpdated(address indexed token, uint256 mintFee);

    error MintFeeExceedsMaxBps();

    uint256 public defaultMintFee;

    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner, address _platformFeeRecipient, uint256 _defaultMintFee) external initializer {
        _initializeOwner(_owner);

        platformFeeRecipient = _platformFeeRecipient;
        defaultMintFee = _defaultMintFee;
    }

    function setPlatformFeeRecipient(address _platformFeeRecipient) external onlyOwner {
        platformFeeRecipient = _platformFeeRecipient;
    }

    function setDefaultMintFee(uint256 _defaultMintFee) external onlyOwner {
        defaultMintFee = _defaultMintFee;
    }

    /**
     * @notice updates the mint fee for the specified contract
     * @param _contract the address of the token to be updated
     * @param _mintFee the new mint fee for the token
     * @dev a mint fee of 0 means they are registered under the default mint fee
     */
    function updateMintFee(address _contract, uint256 _mintFee) external onlyOwner {
        if (_mintFee > 10_000 && _mintFee != type(uint256).max) {
            revert MintFeeExceedsMaxBps();
        }
        mintFees[_contract] = _mintFee;

        emit MintFeeUpdated(_contract, _mintFee);
    }

    /**
     * @notice returns the mint fee for the specified contract and the platform fee recipient
     * @return the mint fee for the specified contract and the platform fee recipient
     * @dev a mint fee of 1 means they are subject to zero mint feedo not have a mint fee sets
     */
    function getPlatformFeeAndRecipient() external view returns (uint256, address) {
        uint256 mintFee;

        if (mintFees[msg.sender] == 0) {
            return (defaultMintFee, platformFeeRecipient);
        }
        if (mintFees[msg.sender] == type(uint256).max) {
            return (0, platformFeeRecipient);
        }

        return (mintFees[msg.sender], platformFeeRecipient);
    }

}

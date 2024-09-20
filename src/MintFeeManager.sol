// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// OZ libraries
import {Ownable} from "@solady/auth/Ownable.sol";
import {Initializable} from "@solady/utils/Initializable.sol";

contract MintFeeManager is Ownable, Initializable {

    uint256 private constant MINT_FEE_MAX_BPS = 10_000;
    address public platformFeeRecipient;
    uint256 public defaultMintFee;

    mapping(address => uint256) public mintFees;

    event MintFeeUpdated(address indexed contractAddress, uint256 mintFee);
    event DefaultMintFeeUpdated(uint256 mintFee);

    error MintFeeExceedsMaxBps();

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
        if (_defaultMintFee > MINT_FEE_MAX_BPS) {
            revert MintFeeExceedsMaxBps();
        }
        defaultMintFee = _defaultMintFee;

        emit DefaultMintFeeUpdated(_defaultMintFee);
    }

    /**
     * @notice updates the mint fee for the specified contract
     * @param _contract the address of the token to be updated
     * @param _mintFee the new mint fee for the token
     * @dev a mint fee of 0 means they are registered under the default mint fee
     */
    function updateMintFee(address _contract, uint256 _mintFee) external onlyOwner {
        if (_mintFee > MINT_FEE_MAX_BPS && _mintFee != type(uint256).max) {
            revert MintFeeExceedsMaxBps();
        }
        mintFees[_contract] = _mintFee;

        emit MintFeeUpdated(_contract, _mintFee);
    }

    /**
     * @notice returns the mint fee for the specified contract and the platform fee recipient
     * @param _price the price of the token to be minted
     * @return the mint fee for the specified contract and the platform fee recipient
     * @dev a mint fee of uint256 max means they are subject to zero mint fees
     */
    function getPlatformFeeAndRecipient(uint256 _price) external view returns (uint256, address) {
        uint256 mintFee;

        if (mintFees[msg.sender] == 0) {
            mintFee = (_price * defaultMintFee) / MINT_FEE_MAX_BPS;
        } else if (mintFees[msg.sender] != type(uint256).max) {
            mintFee = (_price * mintFees[msg.sender]) / MINT_FEE_MAX_BPS;
        }

        return (mintFee, platformFeeRecipient);
    }

}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Module} from "../Module.sol";
import {Role} from "../Role.sol";

library MintFeeManagerStorage {

    /// @custom:storage-location erc7201:mint.fee.manager
    bytes32 public constant MINT_FEE_MANAGER_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("mint.fee.manager")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        address feeRecipient;
        uint256 defaultMintFee;
        mapping(address _contract => uint256 mintFee) mintFees;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = MINT_FEE_MANAGER_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }

}

contract MintFeeManagerModule is Module {

    uint256 private constant MINT_FEE_MAX_BPS = 10_000;

    event MintFeeUpdated(address indexed contractAddress, uint256 mintFee);
    event DefaultMintFeeUpdated(uint256 mintFee);
    event feeRecipientUpdated(address feeRecipient);

    error MintFeeExceedsMaxBps();

    function getModuleConfig() external pure override returns (ModuleConfig memory config) {
        config.fallbackFunctions = new FallbackFunction[](7);

        config.fallbackFunctions[0] = FallbackFunction({selector: this.getfeeRecipient.selector, permissionBits: 0});
        config.fallbackFunctions[1] =
            FallbackFunction({selector: this.setfeeRecipient.selector, permissionBits: Role._MANAGER_ROLE});
        config.fallbackFunctions[2] = FallbackFunction({selector: this.getDefaultMintFee.selector, permissionBits: 0});
        config.fallbackFunctions[3] =
            FallbackFunction({selector: this.setDefaultMintFee.selector, permissionBits: Role._MANAGER_ROLE});
        config.fallbackFunctions[4] = FallbackFunction({selector: this.getMintFees.selector, permissionBits: 0});
        config.fallbackFunctions[5] =
            FallbackFunction({selector: this.updateMintFee.selector, permissionBits: Role._MANAGER_ROLE});
        config.fallbackFunctions[6] =
            FallbackFunction({selector: this.calculatePlatformFeeAndRecipient.selector, permissionBits: 0});

        config.registerInstallationCallback = true;
    }

    /// @dev Called by a Core into an Module during the installation of the Module.
    function onInstall(bytes calldata data) external {
        (address _feeRecipient, uint256 _defaultMintFee) = abi.decode(data, (address, uint256));
        setfeeRecipient(_feeRecipient);
        setDefaultMintFee(_defaultMintFee);
    }

    /// @dev Called by a Core into an Module during the uninstallation of the Module.
    function onUninstall(bytes calldata data) external {}

    /*//////////////////////////////////////////////////////////////
                    Encode install / uninstall data
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns bytes encoded install params, to be sent to `onInstall` function
    function encodeBytesOnInstall(address _feeRecipient, uint256 _defaultMintFee)
        external
        pure
        returns (bytes memory)
    {
        return abi.encode(_feeRecipient, _defaultMintFee);
    }

    /// @dev Returns bytes encoded uninstall params, to be sent to `onUninstall` function
    function encodeBytesOnUninstall() external pure returns (bytes memory) {
        return "";
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getfeeRecipient() external view returns (address) {
        return _mintFeeManagerStorage().feeRecipient;
    }

    function setfeeRecipient(address _feeRecipient) public {
        _mintFeeManagerStorage().feeRecipient = _feeRecipient;

        emit feeRecipientUpdated(_feeRecipient);
    }

    function getDefaultMintFee() external view returns (uint256) {
        return _mintFeeManagerStorage().defaultMintFee;
    }

    function setDefaultMintFee(uint256 _defaultMintFee) public {
        if (_defaultMintFee > MINT_FEE_MAX_BPS) {
            revert MintFeeExceedsMaxBps();
        }
        _mintFeeManagerStorage().defaultMintFee = _defaultMintFee;

        emit DefaultMintFeeUpdated(_defaultMintFee);
    }

    function getMintFees(address _contract) external view returns (uint256) {
        return _mintFeeManagerStorage().mintFees[_contract];
    }

    /**
     * @notice updates the mint fee for the specified contract
     * @param _contract the address of the token to be updated
     * @param _mintFee the new mint fee for the contract
     * @dev a mint fee of 0 means they are registered under the default mint fee
     */
    function updateMintFee(address _contract, uint256 _mintFee) external {
        if (_mintFee > MINT_FEE_MAX_BPS && _mintFee != type(uint256).max) {
            revert MintFeeExceedsMaxBps();
        }
        _mintFeeManagerStorage().mintFees[_contract] = _mintFee;

        emit MintFeeUpdated(_contract, _mintFee);
    }

    /**
     * @notice returns the mint fee for the specified contract and the platform fee recipient
     * @param _price the price of the token to be minted
     * @return the mint fee for the specified contract and the platform fee recipient
     * @dev a mint fee of uint256 max means they are subject to zero mint fees
     */
    function calculatePlatformFeeAndRecipient(uint256 _price) external view returns (uint256, address) {
        uint256 mintFee;

        if (_mintFeeManagerStorage().mintFees[msg.sender] == 0) {
            mintFee = (_price * _mintFeeManagerStorage().defaultMintFee) / MINT_FEE_MAX_BPS;
        } else if (_mintFeeManagerStorage().mintFees[msg.sender] != type(uint256).max) {
            mintFee = (_price * _mintFeeManagerStorage().mintFees[msg.sender]) / MINT_FEE_MAX_BPS;
        }

        return (mintFee, _mintFeeManagerStorage().feeRecipient);
    }

    function _mintFeeManagerStorage() internal pure returns (MintFeeManagerStorage.Data storage) {
        return MintFeeManagerStorage.data();
    }

}

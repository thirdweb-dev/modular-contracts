// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IFeeConfig} from "../../interface/extension/IFeeConfig.sol";
import {IPermission} from "../../interface/extension/IPermission.sol";
import {TokenHook} from "../../extension/TokenHook.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";

contract SimpleDistributeHook is IFeeConfig, TokenHook {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The bits that represent the admin role.
    uint96 public constant ADMIN_ROLE_BITS = 2 ** 1;

    /// @notice The address considered as native token.
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when incorrect native token value is sent.
    error IncorrectValueSent();

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from token => fee config for the token.
    mapping(address => FeeConfig) private _feeConfig;

    /*//////////////////////////////////////////////////////////////
                               MODIFIER
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks whether the caller is an admin of the given token.
    modifier onlyAdmin(address _token) {
        require(IPermission(_token).hasRole(msg.sender, ADMIN_ROLE_BITS), "not authorized");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all hook functions implemented by this hook contract.
    function getHooksImplemented() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = DISTRIBUTE_SALE_VALUE_FLAG;
    }

    /// @notice Returns the fee config for a token.
    function getFeeConfig(address _token) external view returns (FeeConfig memory) {
        return _feeConfig[_token];
    }

    /*//////////////////////////////////////////////////////////////
                        SALE VALUE DISTRIBUTE HOOK
    //////////////////////////////////////////////////////////////*/

    function distributeSaleValue(address _minter, uint256 _totalPrice, address _currency) external payable override {
        if (_totalPrice == 0) {
            if(msg.value > 0) {
                revert IncorrectValueSent();
            }
            return;
        }

        address token = msg.sender;
        FeeConfig memory feeConfig = _feeConfig[token];

        bool payoutPlatformFees = feeConfig.platformFeeBps > 0 && feeConfig.platformFeeRecipient != address(0);
        uint256 platformFees = 0;

        if (payoutPlatformFees) {
            platformFees = (_totalPrice * feeConfig.platformFeeBps) / 10_000;
        }

        if (_currency == NATIVE_TOKEN) {
            if(msg.value != _totalPrice) {
                revert IncorrectValueSent();
            }
            if (payoutPlatformFees) {
                SafeTransferLib.safeTransferETH(feeConfig.platformFeeRecipient, platformFees);
            }
            SafeTransferLib.safeTransferETH(feeConfig.primarySaleRecipient, _totalPrice - platformFees);
        } else {
            if(msg.value > 0) {
                revert IncorrectValueSent();
            }
            if (payoutPlatformFees) {
                SafeTransferLib.safeTransferFrom(token, _minter, feeConfig.platformFeeRecipient, platformFees);
            }
            SafeTransferLib.safeTransferFrom(
                token, _minter, feeConfig.primarySaleRecipient, _totalPrice - platformFees
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Sets the fee config for a given token.
     *  @param _token The token address.
     *  @param _config The fee config for the token.
     */
    function setFeeConfig(address _token, FeeConfig memory _config) external onlyAdmin(_token) {
        _feeConfig[_token] = _config;
        emit FeeConfigUpdate(_token, _config);
    }
        
}
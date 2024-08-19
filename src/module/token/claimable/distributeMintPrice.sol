pragma solidity ^0.8.20;

import {Role} from "../../../Role.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

library DistributeMintPrice {
    error IncorrectNativeTokenSent();

    address constant NATIVE_TOKEN_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @dev Distributes the mint price to the primary sale recipient and the platform fee recipient.
    function _effectsAndInteractions(
        address _owner,
        address _currency,
        uint256 _price,
        address primarySaleRecipient
    ) internal {
        if (_price == 0) {
            if (msg.value > 0) {
                revert IncorrectNativeTokenSent();
            }
            return;
        }

        if (_currency == NATIVE_TOKEN_ADDRESS) {
            if (msg.value != _price) {
                revert IncorrectNativeTokenSent();
            }
            SafeTransferLib.safeTransferETH(primarySaleRecipient, _price);
        } else {
            if (msg.value > 0) {
                revert IncorrectNativeTokenSent();
            }
            SafeTransferLib.safeTransferFrom(
                _currency,
                _owner,
                primarySaleRecipient,
                _price
            );
        }
    }
}

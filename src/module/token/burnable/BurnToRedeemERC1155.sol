// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Module} from "../../../Module.sol";
import {Role} from "../../../Role.sol";
import {ERC1155} from "@solady/tokens/ERC1155.sol";

contract BurnToRedeemERC1155 is Module, ERC1155 {

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error BurnToRedeemInvalidTokenId();

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event BurnToRedeem(address indexed from, uint256 tokenIdBurned, uint256 tokenIdRedeemed);

    /*//////////////////////////////////////////////////////////////
                            MODULE CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and module functions.
    function getModuleConfig() external pure override returns (ModuleConfig memory config) {
        config.fallbackFunctions = new FallbackFunction[](1);

        config.fallbackFunctions[0] = FallbackFunction({selector: this.burnToRedeem.selector, permissionBits: 0});

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0xd9b67a26; // ERC1155
    }


    /*//////////////////////////////////////////////////////////////
                            ERC1155 FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function uri(uint256 tokenId) public view override returns (string memory) {
        return "";
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set transferability for a token.
    function burnToRedeem(address _from, uint256 _tokenId, uint256 _amount) external {
        if (_tokenId > 4) {
            revert BurnToRedeemInvalidTokenId();
        }
        _burn(msg.sender, _from, _tokenId, _amount);

        uint256 redeemedTokenId = block.number % 99 + 100;

        _mint(msg.sender, redeemedTokenId, 1, "");

        emit BurnToRedeem(msg.sender, _tokenId, redeemedTokenId);
    }
}

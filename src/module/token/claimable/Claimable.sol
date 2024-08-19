// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ModularModule} from "../../../ModularModule.sol";

import {Role} from "../../../Role.sol";
import {IInstallationCallback} from "../../../interface/IInstallationCallback.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {EIP712} from "@solady/utils/EIP712.sol";

import {Mint} from "./Mint.sol";
import {Allowlist} from "./Allowlist.sol";
import {AvailableSupply} from "./AvailableSupply.sol";
import {DistributeMintPrice} from "./DistributeMintPrice.sol";
import {SignatureMint} from "./SignatureMint.sol";
import {TimeWindow} from "./TimeWindow.sol";

import {BeforeMintCallbackERC721} from "../../../callback/BeforeMintCallbackERC721.sol";

library ClaimableStorage {
    /// @custom:storage-location erc7201:token.minting.claimable.erc721
    bytes32 public constant CLAIMABLE_STORAGE_POSITION =
        keccak256(
            abi.encode(uint256(keccak256("token.minting.claimable.erc721")) - 1)
        ) & ~bytes32(uint256(0xff));

    function data() internal pure returns (Mint.Data storage data_) {
        bytes32 position = CLAIMABLE_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract ClaimableERC721 is
    ModularModule,
    SignatureMint,
    BeforeMintCallbackERC721,
    IInstallationCallback
{
    /*//////////////////////////////////////////////////////////////
                            MODULE CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and fallback functions.
    function getModuleConfig()
        external
        pure
        override
        returns (ModuleConfig memory config)
    {
        config.callbackFunctions = new CallbackFunction[](1);
        config.fallbackFunctions = new FallbackFunction[](5);

        config.callbackFunctions[0] = CallbackFunction(
            this.beforeMintERC721.selector
        );

        config.fallbackFunctions[0] = FallbackFunction({
            selector: this.getSaleConfig.selector,
            permissionBits: 0
        });
        config.fallbackFunctions[1] = FallbackFunction({
            selector: this.setSaleConfig.selector,
            permissionBits: Role._MANAGER_ROLE
        });
        config.fallbackFunctions[2] = FallbackFunction({
            selector: this.getClaimCondition.selector,
            permissionBits: 0
        });
        config.fallbackFunctions[3] = FallbackFunction({
            selector: this.setClaimCondition.selector,
            permissionBits: Role._MINTER_ROLE
        });
        config.fallbackFunctions[4] = FallbackFunction({
            selector: this.eip712Domain.selector,
            permissionBits: 0
        });

        config.requiredInterfaces = new bytes4[](1);
        config.requiredInterfaces[0] = 0x80ac58cd; // ERC721.

        config.registerInstallationCallback = true;
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for the ERC721Core.mint function.
    /// @dev NON-SIGNATURE VERSION
    function beforeMintERC721(
        address _to,
        uint256 _startTokenId,
        uint256 _quantity,
        bytes memory _data
    ) external payable virtual override returns (bytes memory) {
        Mint.Params memory _params = abi.decode(_data, (Mint.Params));

        Mint.Conditions memory _conditions = _claimChecks(
            _to,
            _quantity,
            _params
        );
        _claimEffectsAndInteractions(_params, _conditions, _quantity);
    }

    /// @dev Called by a Core into an Module during the installation of the Module.
    function onInstall(bytes calldata data) external {
        address primarySaleRecipient = abi.decode(data, (address));
        _claimableStorage().primarySaleRecipient = primarySaleRecipient;
    }

    /// @dev Called by a Core into an Module during the uninstallation of the Module.
    function onUninstall(bytes calldata data) external {}

    /*//////////////////////////////////////////////////////////////
                    Encode install / uninstall data
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns bytes encoded install params, to be sent to `onInstall` function
    function encodeBytesOnInstall(
        address primarySaleRecipient
    ) external pure returns (bytes memory) {
        return abi.encode(primarySaleRecipient);
    }

    /// @dev Returns bytes encoded uninstall params, to be sent to `onUninstall` function
    function encodeBytesOnUninstall() external pure returns (bytes memory) {
        return "";
    }

    /*//////////////////////////////////////////////////////////////
                        Encode mint params
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns bytes encoded mint params, to be used in `beforeMint` fallback function
    function encodeBytesBeforeMintERC721(
        Mint.Params memory params
    ) external pure returns (bytes memory) {
        return abi.encode(params);
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the sale configuration for a token.
    function getSaleConfig()
        external
        view
        returns (address primarySaleRecipient)
    {
        return _claimableStorage().primarySaleRecipient;
    }

    /// @notice Sets the sale configuration for a token.
    function setSaleConfig(address _primarySaleRecipient) external {
        _claimableStorage().primarySaleRecipient = _primarySaleRecipient;
    }

    /// @notice Returns the claim condition for a token.
    function getClaimCondition()
        external
        view
        returns (Mint.Conditions memory claimCondition)
    {
        return _claimableStorage().conditions;
    }

    /// @notice Sets the claim condition for a token.
    function setClaimCondition(
        Mint.Conditions memory _claimCondition
    ) external {
        _claimableStorage().conditions = _claimCondition;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Verifies a claim against the active claim condition.
    /// TODO: find a way to store data in memory to prevent SLOADs
    ///       issue right now is that the Data struct has a mapping in it
    ///       this prevents it from being stored in memory
    function _claimChecks(
        address _recipient,
        uint256 _amount,
        Mint.Params memory _params
    ) internal returns (Mint.Conditions memory) {
        Mint.Conditions memory _conditions = _params.signature.length == 0
            ? _params.conditions
            : _claimableStorage().conditions;

        TimeWindow._check(_conditions.startTimestamp, _conditions.endTimestamp);
        AvailableSupply._check(
            _conditions.quantity,
            _claimableStorage().availableSupply
        );
        Allowlist._check(
            _params.recipientAllowlistProof,
            _claimableStorage().allowListMerkleRoot,
            _recipient
        );
        _signatureMintCheck(
            _recipient,
            _amount,
            _claimableStorage().uidUsed[_params.signatureRequestUid],
            _params,
            _conditions
        );

        // This is to prevent multiple SLOADs
        return _conditions;
    }

    function _claimEffectsAndInteractions(
        Mint.Params memory _params,
        Mint.Conditions memory _conditions,
        uint256 _quantity
    ) internal {
        Mint.Data storage _data = _claimableStorage();
        _signatureMintEffectsAndInteractions(_data, _params.uid);
        AvailableSupply._effectsAndInteractions(_data, _quantity);
        DistributeMintPrice._effectsAndInteractions(
            msg.sender,
            _conditions.currency,
            _quantity * _conditions.pricePerUnit,
            _data.primarySaleRecipient
        );
    }

    function _claimableStorage() internal pure returns (Mint.Data storage) {
        return ClaimableStorage.data();
    }
}

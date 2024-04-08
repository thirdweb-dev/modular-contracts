// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {IHook} from "@core-contracts/interface/IHook.sol";

import {HookFlagsDirectory} from "@core-contracts/hook/HookFlagsDirectory.sol";
import {BeforeMintHookERC20} from "@core-contracts/hook/BeforeMintHookERC20.sol";
import {BeforeMintHookERC721} from "@core-contracts/hook/BeforeMintHookERC721.sol";
import {BeforeMintHookERC1155} from "@core-contracts/hook/BeforeMintHookERC1155.sol";

import {Ownable} from "@solady/auth/Ownable.sol";
import {Multicallable} from "@solady/utils/Multicallable.sol";
import {MerkleProofLib} from "@solady/utils/MerkleProofLib.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

library ClaimPhaseMintHookStorage {
    /// @custom:storage-location erc7201:mint.hook.storage
    /// @dev keccak256(abi.encode(uint256(keccak256("claim.phase.mint.hook.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant CLAIM_PHASE_MINT_HOOK_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("claim.phase.mint.hook.storage")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        mapping(address => ClaimPhaseMintHook.SaleConfig) saleConfig;
        mapping(address => ClaimPhaseMintHook.ClaimPhase) allowlistClaimPhaseERC20;
        mapping(address => ClaimPhaseMintHook.ClaimPhase) allowlistClaimPhaseERC721;
        mapping(address => mapping(uint256 => ClaimPhaseMintHook.ClaimPhase)) allowlistClaimPhaseERC1155;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = CLAIM_PHASE_MINT_HOOK_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract ClaimPhaseMintHook is
    IHook,
    HookFlagsDirectory,
    BeforeMintHookERC20,
    BeforeMintHookERC721,
    BeforeMintHookERC1155,
    Multicallable
{
    /*//////////////////////////////////////////////////////////////
                            STRUCTS & ENUMS
    //////////////////////////////////////////////////////////////*/

    struct ClaimPhase {
        uint256 availableSupply;
        bytes32 allowlistMerkleRoot;
        uint256 pricePerUnit;
        address currency;
        uint48 startTimestamp;
        uint48 endTimestamp;
    }

    struct ClaimParams {
        bytes32[] allowlistProof;
        uint256 expectedPricePerUnit;
        address expectedCurrency;
    }

    struct SaleConfig {
        address primarySaleRecipient;
        address platformFeeRecipient;
        uint16 platformFeeBps;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error MintHookIncorrectNativeTokenSent();
    error MintHookClaimPhasePriceMismatch();
    error MintHookClaimPhaseOutOfTimeWindow();
    error MintHookClaimPhaseOutOfSupply();
    error MintHookClaimPhaseNotInAllowlist();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address private constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                            HOOK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getHookInfo() external pure returns (HookInfo memory info) {
        info.hookFlags = BEFORE_MINT_ERC20_FLAG | BEFORE_MINT_ERC721_FLAG | BEFORE_MINT_ERC1155_FLAG;
        info.hookFallbackFunctions = new HookFallbackFunction[](8);
        info.hookFallbackFunctions[0] = HookFallbackFunction(this.getSaleConfig.selector, CallType.STATICCALL, false);
        info.hookFallbackFunctions[1] = HookFallbackFunction(this.setSaleConfig.selector, CallType.CALL, true);
        info.hookFallbackFunctions[2] =
            HookFallbackFunction(this.getClaimPhaseERC20.selector, CallType.STATICCALL, false);
        info.hookFallbackFunctions[3] =
            HookFallbackFunction(this.getClaimPhaseERC721.selector, CallType.STATICCALL, false);
        info.hookFallbackFunctions[4] =
            HookFallbackFunction(this.getClaimPhaseERC1155.selector, CallType.STATICCALL, false);
        info.hookFallbackFunctions[5] = HookFallbackFunction(this.setClaimPhaseERC20.selector, CallType.CALL, true);
        info.hookFallbackFunctions[6] = HookFallbackFunction(this.setClaimPhaseERC721.selector, CallType.CALL, true);
        info.hookFallbackFunctions[7] = HookFallbackFunction(this.setClaimPhaseERC1155.selector, CallType.CALL, true);
    }

    function beforeMintERC20(address _to, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        override
        returns (bytes memory)
    {
        ClaimParams memory _params = abi.decode(_data, (ClaimParams));
        _allowlistedMintERC20(_to, _quantity, _params);
    }

    function beforeMintERC721(address _to, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        override
        returns (bytes memory)
    {
        ClaimParams memory _params = abi.decode(_data, (ClaimParams));
        _allowlistedMintERC721(_to, _quantity, _params);
    }

    function beforeMintERC1155(address _to, uint256 _id, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        override
        returns (bytes memory)
    {
        ClaimParams memory _params = abi.decode(_data, (ClaimParams));
        _allowlistedMintERC1155(_to, _id, _quantity, _params);
    }

    /*//////////////////////////////////////////////////////////////
                            ENCODE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function allowlistMint(ClaimParams memory _params) external pure returns (bytes memory) {
        return abi.encode(_params);
    }

    function decodeClaimParams(bytes memory _data) external pure returns (ClaimParams memory) {
        ClaimParams memory _params = abi.decode(_data, (ClaimParams));
        return _params;
    }

    /*//////////////////////////////////////////////////////////////
                            HOOK FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getSaleConfig(address _token)
        external
        view
        returns (address primarySaleRecipient, address platformFeeRecipient, uint16 platformFeeBps)
    {
        SaleConfig memory saleConfig = _claimPhaseMintHookStorage().saleConfig[_token];
        return (saleConfig.primarySaleRecipient, saleConfig.platformFeeRecipient, saleConfig.platformFeeBps);
    }

    function setSaleConfig(address _primarySaleRecipient, address _platformFeeRecipient, uint16 _platformFeeBps)
        external
    {
        address token = msg.sender;
        _claimPhaseMintHookStorage().saleConfig[token] =
            SaleConfig(_primarySaleRecipient, _platformFeeRecipient, _platformFeeBps);
    }

    function getClaimPhaseERC20(address _token) external view returns (ClaimPhase memory claimPhase) {
        return _claimPhaseMintHookStorage().allowlistClaimPhaseERC20[_token];
    }

    function getClaimPhaseERC721(address _token) external view returns (ClaimPhase memory claimPhase) {
        return _claimPhaseMintHookStorage().allowlistClaimPhaseERC721[_token];
    }

    function getClaimPhaseERC1155(address _token, uint256 _id) external view returns (ClaimPhase memory claimPhase) {
        return _claimPhaseMintHookStorage().allowlistClaimPhaseERC1155[_token][_id];
    }

    function setClaimPhaseERC20(ClaimPhase memory _claimPhase) external {
        address token = msg.sender;
        _claimPhaseMintHookStorage().allowlistClaimPhaseERC20[token] = _claimPhase;
    }

    function setClaimPhaseERC721(ClaimPhase memory _claimPhase) external {
        address token = msg.sender;
        _claimPhaseMintHookStorage().allowlistClaimPhaseERC721[token] = _claimPhase;
    }

    function setClaimPhaseERC1155(uint256 _id, ClaimPhase memory _claimPhase) external {
        address token = msg.sender;
        _claimPhaseMintHookStorage().allowlistClaimPhaseERC1155[token][_id] = _claimPhase;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _allowlistedMintERC20(address _recipient, uint256 _quantity, ClaimParams memory _params) internal {
        address token = msg.sender;

        ClaimPhase memory claimPhase = _claimPhaseMintHookStorage().allowlistClaimPhaseERC20[token];

        if (claimPhase.currency != _params.expectedCurrency || claimPhase.pricePerUnit != _params.expectedPricePerUnit)
        {
            revert MintHookClaimPhasePriceMismatch();
        }

        if (block.timestamp < claimPhase.startTimestamp || claimPhase.endTimestamp <= block.timestamp) {
            revert MintHookClaimPhaseOutOfTimeWindow();
        }

        if (_quantity > claimPhase.availableSupply) {
            revert MintHookClaimPhaseOutOfSupply();
        }

        if (claimPhase.allowlistMerkleRoot != bytes32(0)) {
            bool isAllowlisted = MerkleProofLib.verify(
                _params.allowlistProof, claimPhase.allowlistMerkleRoot, keccak256(abi.encodePacked(_recipient))
            );

            if (!isAllowlisted) {
                revert MintHookClaimPhaseNotInAllowlist();
            }
        }

        _claimPhaseMintHookStorage().allowlistClaimPhaseERC20[token].availableSupply -= _quantity;

        _distributeMintPrice(_recipient, _params.expectedCurrency, (_quantity * _params.expectedPricePerUnit) / 1e18);
    }

    function _allowlistedMintERC721(address _recipient, uint256 _quantity, ClaimParams memory _params) internal {
        address token = msg.sender;

        ClaimPhase memory claimPhase = _claimPhaseMintHookStorage().allowlistClaimPhaseERC721[token];

        if (claimPhase.currency != _params.expectedCurrency || claimPhase.pricePerUnit != _params.expectedPricePerUnit)
        {
            revert MintHookClaimPhasePriceMismatch();
        }

        if (block.timestamp < claimPhase.startTimestamp || claimPhase.endTimestamp <= block.timestamp) {
            revert MintHookClaimPhaseOutOfTimeWindow();
        }

        if (_quantity > claimPhase.availableSupply) {
            revert MintHookClaimPhaseOutOfSupply();
        }

        if (claimPhase.allowlistMerkleRoot != bytes32(0)) {
            bool isAllowlisted = MerkleProofLib.verify(
                _params.allowlistProof, claimPhase.allowlistMerkleRoot, keccak256(abi.encodePacked(_recipient))
            );

            if (!isAllowlisted) {
                revert MintHookClaimPhaseNotInAllowlist();
            }
        }

        _claimPhaseMintHookStorage().allowlistClaimPhaseERC721[token].availableSupply -= _quantity;

        _distributeMintPrice(_recipient, _params.expectedCurrency, _quantity * _params.expectedPricePerUnit);
    }

    function _allowlistedMintERC1155(address _recipient, uint256 _id, uint256 _quantity, ClaimParams memory _params)
        internal
    {
        address token = msg.sender;

        ClaimPhase memory claimPhase = _claimPhaseMintHookStorage().allowlistClaimPhaseERC1155[token][_id];

        if (claimPhase.currency != _params.expectedCurrency || claimPhase.pricePerUnit != _params.expectedPricePerUnit)
        {
            revert MintHookClaimPhasePriceMismatch();
        }

        if (block.timestamp < claimPhase.startTimestamp || claimPhase.endTimestamp <= block.timestamp) {
            revert MintHookClaimPhaseOutOfTimeWindow();
        }

        if (_quantity > claimPhase.availableSupply) {
            revert MintHookClaimPhaseOutOfSupply();
        }

        if (claimPhase.allowlistMerkleRoot != bytes32(0)) {
            bool isAllowlisted = MerkleProofLib.verify(
                _params.allowlistProof, claimPhase.allowlistMerkleRoot, keccak256(abi.encodePacked(_recipient))
            );

            if (!isAllowlisted) {
                revert MintHookClaimPhaseNotInAllowlist();
            }
        }

        _claimPhaseMintHookStorage().allowlistClaimPhaseERC1155[token][_id].availableSupply -= _quantity;

        _distributeMintPrice(_recipient, _params.expectedCurrency, _quantity * _params.expectedPricePerUnit);
    }

    function _distributeMintPrice(address _owner, address _currency, uint256 _price) internal {
        if (_price == 0) {
            if (msg.value > 0) {
                revert MintHookIncorrectNativeTokenSent();
            }
            return;
        }

        SaleConfig memory saleConfig = _claimPhaseMintHookStorage().saleConfig[msg.sender];

        uint256 platformFee = (_price * saleConfig.platformFeeBps) / 10_000;

        if (_currency == NATIVE_TOKEN_ADDRESS) {
            if (msg.value != _price) {
                revert MintHookIncorrectNativeTokenSent();
            }
            SafeTransferLib.safeTransferETH(saleConfig.primarySaleRecipient, _price - platformFee);
            SafeTransferLib.safeTransferETH(saleConfig.platformFeeRecipient, platformFee);
        } else {
            SafeTransferLib.safeTransferFrom(_currency, _owner, saleConfig.primarySaleRecipient, _price - platformFee);
            SafeTransferLib.safeTransferFrom(_currency, _owner, saleConfig.platformFeeRecipient, platformFee);
        }
    }

    function _claimPhaseMintHookStorage() internal pure returns (ClaimPhaseMintHookStorage.Data storage) {
        return ClaimPhaseMintHookStorage.data();
    }
}

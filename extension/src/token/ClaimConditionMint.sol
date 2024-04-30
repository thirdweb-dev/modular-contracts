// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {IExtensionContract} from "@core-contracts/interface/IExtensionContract.sol";

import {MerkleProofLib} from "@solady/utils/MerkleProofLib.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

library ClaimConditionMintStorage {
    /// @custom:storage-location erc7201:claim.condition.mint.storage
    bytes32 public constant CLAIM_CONDITION_MINT_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("claim.condition.mint.storage")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        mapping(address => ClaimConditionMint.SaleConfig) saleConfig;
        mapping(address => ClaimConditionMint.ClaimPhase) claimPhase;
        mapping(address => mapping(uint256 => ClaimConditionMint.ClaimPhase)) claimPhaseByTokenId;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = CLAIM_CONDITION_MINT_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

contract ClaimConditionMint is IExtensionContract {
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
    error ClaimConditionMintIncorrectNativeTokenSent();
    error ClaimConditionMintPriceMismatch();
    error ClaimConditionMintOutOfTimeWindow();
    error ClaimConditionMintOutOfSupply();
    error ClaimConditionMintNotInAllowlist();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address private constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                            EXTENSION CONFIG
    //////////////////////////////////////////////////////////////*/

    function getExtensionConfig() external pure returns (ExtensionConfig memory config) {
        config.callbackFunctions = new bytes4[](3);
        config.extensionABI = new ExtensionFunction[](6);

        config.callbackFunctions[0] = this.beforeMintERC20.selector;
        config.callbackFunctions[1] = this.beforeMintERC721.selector;
        config.callbackFunctions[2] = this.beforeMintERC1155.selector;

        config.extensionABI[0] = ExtensionFunction({
            selector: this.getSaleConfig.selector,
            callType: CallType.STATICCALL,
            permissioned: false
        });
        config.extensionABI[1] =
            ExtensionFunction({selector: this.setSaleConfig.selector, callType: CallType.CALL, permissioned: true});
        config.extensionABI[2] = ExtensionFunction({
            selector: this.getClaimPhase.selector,
            callType: CallType.STATICCALL,
            permissioned: false
        });
        config.extensionABI[3] = ExtensionFunction({
            selector: this.getClaimPhaseByTokenId.selector,
            callType: CallType.STATICCALL,
            permissioned: false
        });
        config.extensionABI[4] =
            ExtensionFunction({selector: this.setClaimPhase.selector, callType: CallType.CALL, permissioned: true});
        config.extensionABI[5] = ExtensionFunction({
            selector: this.setClaimPhaseByTokenId.selector,
            callType: CallType.CALL,
            permissioned: true
        });
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function beforeMintERC20(address _to, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        returns (bytes memory)
    {
        ClaimParams memory _params = abi.decode(_data, (ClaimParams));
        _allowlistedMintERC20(_to, _quantity, _params);
    }

    function beforeMintERC721(address _to, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        returns (bytes memory)
    {
        ClaimParams memory _params = abi.decode(_data, (ClaimParams));
        _allowlistedMintERC721(_to, _quantity, _params);
    }

    function beforeMintERC1155(address _to, uint256 _id, uint256 _quantity, bytes memory _data)
        external
        payable
        virtual
        returns (bytes memory)
    {
        ClaimParams memory _params = abi.decode(_data, (ClaimParams));
        _allowlistedMintERC1155(_to, _id, _quantity, _params);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTENSION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getSaleConfig(address _token)
        external
        view
        returns (address primarySaleRecipient, address platformFeeRecipient, uint16 platformFeeBps)
    {
        SaleConfig memory saleConfig = _claimConditionMintStorage().saleConfig[_token];
        return (saleConfig.primarySaleRecipient, saleConfig.platformFeeRecipient, saleConfig.platformFeeBps);
    }

    function setSaleConfig(address _primarySaleRecipient, address _platformFeeRecipient, uint16 _platformFeeBps)
        external
    {
        address token = msg.sender;
        _claimConditionMintStorage().saleConfig[token] =
            SaleConfig(_primarySaleRecipient, _platformFeeRecipient, _platformFeeBps);
    }

    function getClaimPhase(address _token) external view returns (ClaimPhase memory claimPhase) {
        return _claimConditionMintStorage().claimPhase[_token];
    }

    function getClaimPhaseByTokenId(address _token, uint256 _id) external view returns (ClaimPhase memory claimPhase) {
        return _claimConditionMintStorage().claimPhaseByTokenId[_token][_id];
    }

    function setClaimPhase(ClaimPhase memory _claimPhase) external {
        address token = msg.sender;
        _claimConditionMintStorage().claimPhase[token] = _claimPhase;
    }

    function setClaimPhaseByTokenId(uint256 _id, ClaimPhase memory _claimPhase) external {
        address token = msg.sender;
        _claimConditionMintStorage().claimPhaseByTokenId[token][_id] = _claimPhase;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _allowlistedMintERC20(address _recipient, uint256 _quantity, ClaimParams memory _params) internal {
        address token = msg.sender;

        ClaimPhase memory claimPhase = _claimConditionMintStorage().claimPhase[token];

        if (claimPhase.currency != _params.expectedCurrency || claimPhase.pricePerUnit != _params.expectedPricePerUnit)
        {
            revert ClaimConditionMintPriceMismatch();
        }

        if (block.timestamp < claimPhase.startTimestamp || claimPhase.endTimestamp <= block.timestamp) {
            revert ClaimConditionMintOutOfTimeWindow();
        }

        if (_quantity > claimPhase.availableSupply) {
            revert ClaimConditionMintOutOfSupply();
        }

        if (claimPhase.allowlistMerkleRoot != bytes32(0)) {
            bool isAllowlisted = MerkleProofLib.verify(
                _params.allowlistProof, claimPhase.allowlistMerkleRoot, keccak256(abi.encodePacked(_recipient))
            );

            if (!isAllowlisted) {
                revert ClaimConditionMintNotInAllowlist();
            }
        }

        _claimConditionMintStorage().claimPhase[token].availableSupply -= _quantity;

        _distributeMintPrice(_recipient, _params.expectedCurrency, (_quantity * _params.expectedPricePerUnit) / 1e18);
    }

    function _allowlistedMintERC721(address _recipient, uint256 _quantity, ClaimParams memory _params) internal {
        address token = msg.sender;

        ClaimPhase memory claimPhase = _claimConditionMintStorage().claimPhase[token];

        if (claimPhase.currency != _params.expectedCurrency || claimPhase.pricePerUnit != _params.expectedPricePerUnit)
        {
            revert ClaimConditionMintPriceMismatch();
        }

        if (block.timestamp < claimPhase.startTimestamp || claimPhase.endTimestamp <= block.timestamp) {
            revert ClaimConditionMintOutOfTimeWindow();
        }

        if (_quantity > claimPhase.availableSupply) {
            revert ClaimConditionMintOutOfSupply();
        }

        if (claimPhase.allowlistMerkleRoot != bytes32(0)) {
            bool isAllowlisted = MerkleProofLib.verify(
                _params.allowlistProof, claimPhase.allowlistMerkleRoot, keccak256(abi.encodePacked(_recipient))
            );

            if (!isAllowlisted) {
                revert ClaimConditionMintNotInAllowlist();
            }
        }

        _claimConditionMintStorage().claimPhase[token].availableSupply -= _quantity;

        _distributeMintPrice(_recipient, _params.expectedCurrency, _quantity * _params.expectedPricePerUnit);
    }

    function _allowlistedMintERC1155(address _recipient, uint256 _id, uint256 _quantity, ClaimParams memory _params)
        internal
    {
        address token = msg.sender;

        ClaimPhase memory claimPhase = _claimConditionMintStorage().claimPhaseByTokenId[token][_id];

        if (claimPhase.currency != _params.expectedCurrency || claimPhase.pricePerUnit != _params.expectedPricePerUnit)
        {
            revert ClaimConditionMintPriceMismatch();
        }

        if (block.timestamp < claimPhase.startTimestamp || claimPhase.endTimestamp <= block.timestamp) {
            revert ClaimConditionMintOutOfTimeWindow();
        }

        if (_quantity > claimPhase.availableSupply) {
            revert ClaimConditionMintOutOfSupply();
        }

        if (claimPhase.allowlistMerkleRoot != bytes32(0)) {
            bool isAllowlisted = MerkleProofLib.verify(
                _params.allowlistProof, claimPhase.allowlistMerkleRoot, keccak256(abi.encodePacked(_recipient))
            );

            if (!isAllowlisted) {
                revert ClaimConditionMintNotInAllowlist();
            }
        }

        _claimConditionMintStorage().claimPhaseByTokenId[token][_id].availableSupply -= _quantity;

        _distributeMintPrice(_recipient, _params.expectedCurrency, _quantity * _params.expectedPricePerUnit);
    }

    function _distributeMintPrice(address _owner, address _currency, uint256 _price) internal {
        if (_price == 0) {
            if (msg.value > 0) {
                revert ClaimConditionMintIncorrectNativeTokenSent();
            }
            return;
        }

        SaleConfig memory saleConfig = _claimConditionMintStorage().saleConfig[msg.sender];

        uint256 platformFee = (_price * saleConfig.platformFeeBps) / 10_000;

        if (_currency == NATIVE_TOKEN_ADDRESS) {
            if (msg.value != _price) {
                revert ClaimConditionMintIncorrectNativeTokenSent();
            }
            SafeTransferLib.safeTransferETH(saleConfig.primarySaleRecipient, _price - platformFee);
            SafeTransferLib.safeTransferETH(saleConfig.platformFeeRecipient, platformFee);
        } else {
            SafeTransferLib.safeTransferFrom(_currency, _owner, saleConfig.primarySaleRecipient, _price - platformFee);
            SafeTransferLib.safeTransferFrom(_currency, _owner, saleConfig.platformFeeRecipient, platformFee);
        }
    }

    function _claimConditionMintStorage() internal pure returns (ClaimConditionMintStorage.Data storage) {
        return ClaimConditionMintStorage.data();
    }
}

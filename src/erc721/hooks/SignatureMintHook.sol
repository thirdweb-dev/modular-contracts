// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../../interface/extension/IMintRequestERC721.sol";
import "../../interface/extension/IPermission.sol";

import "../../lib/ECDSA.sol";
import "../../lib/SafeTransferLib.sol"; 

import "../../extension/EIP712.sol";
import "../../extension/TokenHook.sol";

contract SignatureMintHook is IMintRequestERC721, EIP712, TokenHook {

    using ECDSA for bytes32;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint96 public constant ADMIN_ROLE_BITS = 2 ** 1;

    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    bytes32 private constant TYPEHASH =
        keccak256(
            "MintRequest(address token,address to,uint256 quantity,uint256 pricePerToken,address currency,uint128 validityStartTimestamp,uint128 validityEndTimestamp,bytes32 uid)"
        );
    
    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct FeeConfig {
        address primarySaleRecipient;
        address platformFeeRecipient;
        uint16 platformFeeBps;
    }

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event NextTokenIdUpdate(address indexed token, uint256 nextTokenIdToMint);
    event FeeConfigUpdate(address indexed token, FeeConfig feeConfig);

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint256) private _nextTokenIdToMint;
    mapping(address => FeeConfig) private _feeConfig;
    mapping(bytes32 => bool) private minted;

    /*//////////////////////////////////////////////////////////////
                               MODIFIER
    //////////////////////////////////////////////////////////////*/

    modifier onlyAdmin(address _token) {
        require(IPermission(_token).hasRole(msg.sender, ADMIN_ROLE_BITS), "not authorized");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getHooksImplemented() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = BEFORE_MINT_FLAG;
    }

    function getBeforeMintArgSignature() external pure override returns (string memory argSignature) {
        argSignature = "address,address,uint256,uint256,address,uint128,uint128,bytes32,bytes";
    }

    function verify(
        address _token,
        MintRequestERC721 memory _req,
        bytes memory _signature
    ) public view returns (bool success, address signer) {
        signer = _recoverAddress(_req, _signature);
        success = !minted[keccak256(abi.encode(_token, _req.uid))] 
            && _token == _req.token
            && IPermission(_token).hasRole(signer, ADMIN_ROLE_BITS);
    }

    /*//////////////////////////////////////////////////////////////
                            BEFORE MINT HOOK
    //////////////////////////////////////////////////////////////*/

    function beforeMint(address _claimer, uint256 _quantity, bytes memory _data)
        external
        payable
        override
        returns (uint256 tokenIdToMint)
    {
        address token = msg.sender;

        (
            MintRequestERC721 memory req,
            bytes memory signature
        ) = abi.decode(_data, (MintRequestERC721, bytes));
        require(req.quantity == _quantity, "Invalid quantity");

        tokenIdToMint = _nextTokenIdToMint[token]++;
        _processRequest(token, req, signature);

        _collectPriceOnClaim(token, _claimer, _quantity, req.currency, req.pricePerToken);
    }

    /*//////////////////////////////////////////////////////////////
                            SETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setNextIdToMint(address _token, uint256 _nextIdToMint) external onlyAdmin(_token) {
        _nextTokenIdToMint[_token] = _nextIdToMint;
        emit NextTokenIdUpdate(_token, _nextIdToMint);
    }

    function setFeeConfig(address _token, FeeConfig calldata _config) external onlyAdmin(_config.primarySaleRecipient) {
        _feeConfig[_token] = _config;
        emit FeeConfigUpdate(_token, _config);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _domainNameAndVersion()
        internal
        pure
        override
        returns (string memory name, string memory version) 
    {
        name = "SignatureMintERC721";
        version = "1";
    }

    function _recoverAddress(MintRequestERC721 memory _req, bytes memory _signature) internal view returns (address) {
        return _hashTypedData(
            keccak256(
                abi.encode(
                    TYPEHASH,
                    _req.token,
                    _req.to,
                    _req.quantity,
                    _req.pricePerToken,
                    _req.currency,
                    _req.validityStartTimestamp,
                    _req.validityEndTimestamp,
                    _req.uid
                )
            )
        ).recover(_signature);
    }

    function _processRequest(address _token, MintRequestERC721 memory _req, bytes memory _signature) internal {
        bool success;
        address signer;
        (success, signer) = verify(_token, _req, _signature);

        if (!success) {
            revert("Invalid req");
        }

        if (_req.validityStartTimestamp > block.timestamp || block.timestamp > _req.validityEndTimestamp) {
            revert("Req expired");
        }
        require(_req.to != address(0), "recipient undefined");
        require(_req.quantity > 0, "0 qty");

        minted[keccak256(abi.encode(_token, _req.uid))] = true;
    }

    function _collectPriceOnClaim(
        address _token,
        address _claimer,
        uint256 _quantityToClaim,
        address _currency,
        uint256 _pricePerToken
    ) internal {
        if (_pricePerToken == 0) {
            require(msg.value == 0, "!Value");
            return;
        }

        FeeConfig memory feeConfig = _feeConfig[_token];

        uint256 totalPrice = _quantityToClaim * _pricePerToken;
        
        bool payoutPlatformFees = feeConfig.platformFeeBps > 0 && feeConfig.platformFeeRecipient != address(0);
        uint256 platformFees = 0;

        if(payoutPlatformFees) {
            platformFees = (totalPrice * feeConfig.platformFeeBps) / 10_000;
        }

        if (_currency == NATIVE_TOKEN) {
            require(msg.value == totalPrice, "!Price");
            if(payoutPlatformFees) {
                SafeTransferLib.safeTransferETH(feeConfig.platformFeeRecipient, platformFees);
            }
            SafeTransferLib.safeTransferETH(feeConfig.primarySaleRecipient, totalPrice - platformFees);
        } else {
            require(msg.value == 0, "!Value");
            if(payoutPlatformFees) {
                SafeTransferLib.safeTransferFrom(_token, _claimer, feeConfig.platformFeeRecipient, platformFees);    
            }
            SafeTransferLib.safeTransferFrom(_token, _claimer, feeConfig.platformFeeRecipient, platformFees);
            SafeTransferLib.safeTransferFrom(_token, _claimer, feeConfig.primarySaleRecipient, totalPrice - platformFees);
        }
    }
}
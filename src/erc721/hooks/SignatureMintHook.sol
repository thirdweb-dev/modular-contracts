// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IMintRequestERC721} from "../../interface/extension/IMintRequestERC721.sol";
import {IPermission} from "../../interface/extension/IPermission.sol";
import {IFeeConfig} from "../../interface/extension/IFeeConfig.sol";
import {ECDSA} from "../../lib/ECDSA.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";
import {EIP712} from "../../extension/EIP712.sol";
import {TokenHook} from "../../extension/TokenHook.sol";

contract SignatureMintHook is IMintRequestERC721, IFeeConfig, EIP712, TokenHook {
    using ECDSA for bytes32;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The bits that represent the admin role.
    uint96 public constant ADMIN_ROLE_BITS = 2 ** 1;

    /// @notice The address considered as native token.
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice The EIP-712 typehash for the mint request struct.
    bytes32 private constant TYPEHASH = keccak256(
        "MintRequest(address token,address to,uint256 quantity,uint256 pricePerToken,address currency,uint128 validityStartTimestamp,uint128 validityEndTimestamp,bytes32 uid)"
    );

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the next token ID to mint is updated.
    event NextTokenIdUpdate(address indexed token, uint256 nextTokenIdToMint);

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from token => the next token ID to mint.
    mapping(address => uint256) private _nextTokenIdToMint;

    /// @notice Mapping from token => fee config for the token.
    mapping(address => FeeConfig) private _feeConfig;

    /// @dev Mapping from request UID => whether the mint request is processed.
    mapping(bytes32 => bool) private minted;

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
        hooksImplemented = BEFORE_MINT_FLAG;
    }

    /// @notice Returns the signature of the arguments expected by the beforeMint hook.
    function getBeforeMintArgSignature() external pure override returns (string memory argSignature) {
        argSignature = "address,address,uint256,uint256,address,uint128,uint128,bytes32,bytes";
    }

    /// @notice Returns the next token ID to mint for a given token.
    function getNextTokenIdToMint(address _token) external view returns (uint256) {
        return _nextTokenIdToMint[_token];
    }

    /**
     *  @notice Verifies the mint request for minting a given token.
     *  @param _token The token address.
     *  @param _req The mint request.
     *  @param _signature The signature of the mint request.
     */
    function verify(address _token, MintRequestERC721 memory _req, bytes memory _signature)
        public
        view
        returns (bool success, address signer)
    {
        signer = _recoverAddress(_req, _signature);
        success = !minted[_req.uid] && _token == _req.token && IPermission(_token).hasRole(signer, ADMIN_ROLE_BITS);
    }

    /*//////////////////////////////////////////////////////////////
                            BEFORE MINT HOOK
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The beforeMint hook that is called by a core token before minting a token.
     *  @param _claimer The address that is minting tokens.
     *  @param _quantity The quantity of tokens to mint.
     *  @param _encodedArgs The encoded arguments for the beforeMint hook.
     *  @return tokenIdToMint The token ID to start minting the given quantity tokens from.
     */
    function beforeMint(address _claimer, uint256 _quantity, bytes memory _encodedArgs)
        external
        payable
        override
        returns (uint256 tokenIdToMint, uint256 quantityToMint)
    {
        address token = msg.sender;
        quantityToMint = _quantity;

        (MintRequestERC721 memory req, bytes memory signature) = abi.decode(_encodedArgs, (MintRequestERC721, bytes));
        require(req.quantity == _quantity, "Invalid quantity");

        tokenIdToMint = _nextTokenIdToMint[token]++;
        _processRequest(token, req, signature);

        _collectPriceOnClaim(token, _claimer, _quantity, req.currency, req.pricePerToken);
    }

    /*//////////////////////////////////////////////////////////////
                            SETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Sets the next token ID to mint for a given token.
     *  @dev Only callable by an admin of the given token.
     *  @param _token The token to set the next token ID to mint for.
     *  @param _nextIdToMint The next token ID to mint.
     */
    function setNextIdToMint(address _token, uint256 _nextIdToMint) external onlyAdmin(_token) {
        _nextTokenIdToMint[_token] = _nextIdToMint;
        emit NextTokenIdUpdate(_token, _nextIdToMint);
    }

    /**
     *  @notice Sets the fee config for a given token.
     *  @dev Only callable by an admin of the given token.
     *  @param _token The token to set the fee config for.
     *  @param _config The fee config to set.
     */
    function setFeeConfig(address _token, FeeConfig calldata _config) external onlyAdmin(_token) {
        _feeConfig[_token] = _config;
        emit FeeConfigUpdate(_token, _config);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the domain name and version for the EIP-712 domain separator
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "SignatureMintERC721";
        version = "1";
    }

    /// @dev Returns the address of the signer of the mint request.
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

    /// @dev Verified and processes the mint request as used for minting a token.
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

        minted[_req.uid] = true;
    }

    /// @dev Transfers the sale price of minting based on the fee config set.
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

        if (payoutPlatformFees) {
            platformFees = (totalPrice * feeConfig.platformFeeBps) / 10_000;
        }

        if (_currency == NATIVE_TOKEN) {
            require(msg.value == totalPrice, "!Price");
            if (payoutPlatformFees) {
                SafeTransferLib.safeTransferETH(feeConfig.platformFeeRecipient, platformFees);
            }
            SafeTransferLib.safeTransferETH(feeConfig.primarySaleRecipient, totalPrice - platformFees);
        } else {
            require(msg.value == 0, "!Value");
            if (payoutPlatformFees) {
                SafeTransferLib.safeTransferFrom(_token, _claimer, feeConfig.platformFeeRecipient, platformFees);
            }
            SafeTransferLib.safeTransferFrom(_token, _claimer, feeConfig.platformFeeRecipient, platformFees);
            SafeTransferLib.safeTransferFrom(
                _token, _claimer, feeConfig.primarySaleRecipient, totalPrice - platformFees
            );
        }
    }
}

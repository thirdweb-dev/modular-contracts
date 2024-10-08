// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Module} from "../../../Module.sol";

import {Role} from "../../../Role.sol";

import {IERC20} from "../../../interface/IERC20.sol";
import {IInstallationCallback} from "../../../interface/IInstallationCallback.sol";
import {CrossChain} from "./CrossChain.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";

import {CCIPReceiver} from "@chainlink/ccip/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/ccip/libraries/Client.sol";

library ChainlinkCrossChainStorage {

    /// @custom:storage-location erc7201:token.minting.chainlinkcrosschain
    bytes32 public constant CHAINLINKCROSSCHAIN_STORAGE_POSITION = keccak256(
        abi.encode(uint256(keccak256("token.minting.chainlinkcrosschain.erc721")) - 1)
    ) & ~bytes32(uint256(0xff));

    struct Data {
        address router;
        address linkToken;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = CHAINLINKCROSSCHAIN_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }

}

contract ChainlinkCrossChain is Module, CrossChain, CCIPReceiver {

    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);

    constructor(address _router, address _link) CCIPReceiver(_router) {}

    /*//////////////////////////////////////////////////////////////
                            MODULE CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all implemented callback and fallback functions.
    function getModuleConfig() external pure override returns (ModuleConfig memory config) {
        config.fallbackFunctions = new FallbackFunction[](5);

        config.fallbackFunctions[0] = FallbackFunction({selector: this.getRouter.selector, permissionBits: 0});
        config.fallbackFunctions[1] = FallbackFunction({selector: this.getLinkToken.selector, permissionBits: 0});
        config.fallbackFunctions[2] =
            FallbackFunction({selector: this.setRouter.selector, permissionBits: Role._MANAGER_ROLE});
        config.fallbackFunctions[3] =
            FallbackFunction({selector: this.setLinkToken.selector, permissionBits: Role._MANAGER_ROLE});
        config.fallbackFunctions[4] =
            FallbackFunction({selector: this.sendCrossChainTransaction.selector, permissionBits: 0});

        config.registerInstallationCallback = true;
    }

    /*//////////////////////////////////////////////////////////////
                    INSTALL / UNINSTALL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Called by a Core into an Module during the installation of the Module.
    function onInstall(bytes calldata data) external {
        (address router, address linkToken) = abi.decode(data, (address, address));
        _chainlinkCrossChainStorage().router = router;
        _chainlinkCrossChainStorage().linkToken = linkToken;
    }

    /// @dev Called by a Core into an Module during the uninstallation of the Module.
    function onUninstall(bytes calldata data) external {}

    /// @dev Returns bytes encoded install params, to be sent to `onInstall` function
    function encodeBytesOnInstall(address router, address linkToken) external pure returns (bytes memory) {
        return abi.encode(router, linkToken);
    }

    /// @dev Returns bytes encoded uninstall params, to be sent to `onUninstall` function
    function encodeBytesOnUninstall() external pure returns (bytes memory) {
        return "";
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getRouter() public view override(CrossChain, CCIPReceiver) returns (address) {
        return _chainlinkCrossChainStorage().router;
    }

    function getLinkToken() external view returns (address) {
        return _chainlinkCrossChainStorage().linkToken;
    }

    function setRouter(address router) external override {
        _chainlinkCrossChainStorage().router = router;
    }

    function setLinkToken(address linkToken) external {
        _chainlinkCrossChainStorage().linkToken = linkToken;
    }

    function sendCrossChainTransaction(
        uint64 _destinationChain,
        address _callAddress,
        bytes calldata _data,
        bytes calldata _extraArgs
    ) external payable override {
        (
            address _recipient,
            address _token,
            uint256 _amount,
            address _feeTokenAddress,
            bytes memory ccipMessageExtraArgs
        ) = abi.decode(_extraArgs, (address, address, uint256, address, bytes));

        if (_feeTokenAddress == address(0)) {
            _sendMessagePayNative(_destinationChain, _recipient, _data, _token, _amount, ccipMessageExtraArgs);
        } else {
            _sendMessagePayToken(
                _destinationChain, _recipient, _data, _token, _amount, _feeTokenAddress, ccipMessageExtraArgs
            );
        }

        onCrossChainTransactionSent(_destinationChain, _callAddress, _data, _extraArgs);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function onCrossChainTransactionSent(
        uint64 _destinationChain,
        address _callAddress,
        bytes calldata _payload,
        bytes calldata _extraArgs
    ) internal override {
        /// post cross chain transaction sent logic goes here
    }

    function onCrossChainTransactionReceived(
        uint64 _sourceChain,
        address _sourceAddress,
        bytes memory _payload,
        bytes memory _extraArgs
    ) internal override {
        /// post cross chain transaction received logic goes here
    }

    function _sendMessagePayToken(
        uint64 _destinationChain,
        address _recipient,
        bytes calldata _data,
        address _token,
        uint256 _amount,
        address _feeTokenAddress,
        bytes memory _extraArgs
    ) internal {
        Client.EVM2AnyMessage memory evm2AnyMessage =
            _buildCCIPMessage(_recipient, _data, _token, _amount, _feeTokenAddress, _extraArgs);
        IRouterClient router = IRouterClient(_chainlinkCrossChainStorage().router);
        uint256 fees = router.getFee(_destinationChain, evm2AnyMessage);
        IERC20 linkToken = IERC20(_chainlinkCrossChainStorage().linkToken);

        if (fees > linkToken.balanceOf(address(this))) {
            revert NotEnoughBalance(linkToken.balanceOf(address(this)), fees);
        }

        IERC20(linkToken).approve(address(router), fees);
        IERC20(_token).approve(address(router), _amount);
        router.ccipSend(_destinationChain, evm2AnyMessage);
    }

    function _sendMessagePayNative(
        uint64 _destinationChain,
        address _recipient,
        bytes calldata _data,
        address _token,
        uint256 _amount,
        bytes memory _extraArgs
    ) internal {
        Client.EVM2AnyMessage memory evm2AnyMessage =
            _buildCCIPMessage(_recipient, _data, _token, _amount, address(0), _extraArgs);
        IRouterClient router = IRouterClient(_chainlinkCrossChainStorage().router);
        uint256 fees = router.getFee(_destinationChain, evm2AnyMessage);

        if (fees > address(this).balance) {
            revert NotEnoughBalance(address(this).balance, fees);
        }

        IERC20(_token).approve(address(router), _amount);
        router.ccipSend{value: fees}(_destinationChain, evm2AnyMessage);
    }

    function _buildCCIPMessage(
        address _recipient,
        bytes calldata _data,
        address _token,
        uint256 _amount,
        address _feeTokenAddress,
        bytes memory _extraArgs
    ) private pure returns (Client.EVM2AnyMessage memory) {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: _token, amount: _amount});

        return Client.EVM2AnyMessage({
            receiver: abi.encode(_recipient),
            data: _data,
            tokenAmounts: tokenAmounts,
            extraArgs: _extraArgs,
            feeToken: _feeTokenAddress
        });
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        address sender = abi.decode(message.sender, (address));
        bytes memory payload = "";
        onCrossChainTransactionReceived(message.sourceChainSelector, sender, message.data, payload);
    }

    function _chainlinkCrossChainStorage() internal pure returns (ChainlinkCrossChainStorage.Data storage) {
        return ChainlinkCrossChainStorage.data();
    }

}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Module} from "../../../Module.sol";

import {Role} from "../../../Role.sol";
import {IERC20} from "../../../interface/IERC20.sol";

library ZetaChainCrossChainStorage {

    /// @custom:storage-location erc7201:token.minting.mintable
    bytes32 public constant ZETACHAIN_CROSS_CHAIN_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("token.crosschain.zetachain")) - 1)) & ~bytes32(uint256(0xff));

    struct Data {
        address erc20Custody;
        address tss;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = ZETACHAIN_CROSS_CHAIN_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }

}

interface IERC20Custody {

    function deposit(bytes calldata recipient, IERC20 asset, uint256 amount, bytes calldata message) external;

}

contract ZetaChainCrossChain is Module {

    /*//////////////////////////////////////////////////////////////
                            MODULE CONFIG
    //////////////////////////////////////////////////////////////*/

    function getModuleConfig() external pure virtual override returns (ModuleConfig memory config) {
        config.callbackFunctions = new CallbackFunction[](1);
        config.fallbackFunctions = new FallbackFunction[](5);

        config.fallbackFunctions[0] =
            FallbackFunction({selector: this.sendCrossChainTransaction.selector, permissionBits: 0});
        config.fallbackFunctions[2] = FallbackFunction({selector: this.getTss.selector, permissionBits: 0});
        config.fallbackFunctions[4] = FallbackFunction({selector: this.getERC20Custody.selector, permissionBits: 0});
        config.fallbackFunctions[1] =
            FallbackFunction({selector: this.setTss.selector, permissionBits: Role._MANAGER_ROLE});
        config.fallbackFunctions[3] =
            FallbackFunction({selector: this.setERC20Custody.selector, permissionBits: Role._MANAGER_ROLE});

        config.registerInstallationCallback = true;
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Called by a Core into an Module during the installation of the Module.
    function onInstall(bytes calldata data) external {
        (address tss, address erc20Custody) = abi.decode(data, (address, address));
        _zetaChainCrossChainStorage().tss = tss;
        _zetaChainCrossChainStorage().erc20Custody = erc20Custody;
    }

    /// @dev Called by a Core into an Module during the uninstallation of the Module.
    function onUninstall(bytes calldata data) external {}

    /*//////////////////////////////////////////////////////////////
                    Encode install / uninstall data
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns bytes encoded install params, to be sent to `onInstall` function
    function encodeBytesOnInstall(address tss, address erc20Custody) external pure returns (bytes memory) {
        return abi.encode(tss, erc20Custody);
    }

    /// @dev Returns bytes encoded uninstall params, to be sent to `onUninstall` function
    function encodeBytesOnUninstall() external pure returns (bytes memory) {
        return "";
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function sendCrossChainTransaction(
        uint64 _destinationChain,
        address _callAddress,
        address _recipient,
        address _token,
        uint256 _amount,
        bytes calldata _data,
        bytes memory _extraArgs
    ) external {
        // Mimics the encoding of the ZetaChain client library
        // https://github.com/zeta-chain/toolkit/tree/main/packages/client/src
        bytes memory encodedData = abi.encodePacked(_callAddress, _data);
        if (_token == address(0)) {
            (bool success,) = payable(_zetaChainCrossChainStorage().tss).call{value: _amount}(encodedData);
            require(success, "Failed to send message");
        } else {
            IERC20Custody(_zetaChainCrossChainStorage().erc20Custody).deposit(
                abi.encode(_recipient), IERC20(_token), _amount, encodedData
            );
        }
    }

    function getTss() external view returns (address) {
        return _zetaChainCrossChainStorage().tss;
    }

    function setTss(address _tss) external {
        _zetaChainCrossChainStorage().tss = _tss;
    }

    function getERC20Custody() external view returns (address) {
        return _zetaChainCrossChainStorage().erc20Custody;
    }

    function setERC20Custody(address _erc20Custody) external {
        _zetaChainCrossChainStorage().erc20Custody = _erc20Custody;
    }

    function _zetaChainCrossChainStorage() internal pure returns (ZetaChainCrossChainStorage.Data storage) {
        return ZetaChainCrossChainStorage.data();
    }

}

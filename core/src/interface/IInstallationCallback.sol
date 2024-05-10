// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

interface IInstallationCallback {
    function onInstall(address sender, bytes calldata data) external;

    function onUninstall(address sender, bytes calldata data) external;
}

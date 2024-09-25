pragma solidity ^0.8.20;

import {SplitWalletCore} from "../core/SplitWalletCore.sol";
import {IERC20} from "../interface/IERC20.sol";

import {Module} from "../Module.sol";

contract SplitWalletModule is Module {

    error OnlySplitFees();

    modifier onlySplitFees() {
        if (msg.sender != SplitWalletCore(payable(address(this))).splitFees()) {
            revert OnlySplitFees();
        }
        _;
    }

    function getModuleConfig() external pure virtual override returns (ModuleConfig memory) {
        ModuleConfig memory config;
        config.fallbackFunctions = new FallbackFunction[](2);
        config.fallbackFunctions[0] = FallbackFunction({selector: this.transferETH.selector, permissionBits: 0});
        config.fallbackFunctions[1] = FallbackFunction({selector: this.transferERC20.selector, permissionBits: 0});

        return config;
    }

    function transferETH(uint256 amount) external payable onlySplitFees {
        address payable splitFees = payable(SplitWalletCore(payable(address(this))).splitFees());
        (bool success,) = splitFees.call{value: amount}("");
        require(success, "Failed to send Ether");
    }

    function transferERC20(address token, uint256 amount) external onlySplitFees {
        address splitFees = SplitWalletCore(payable(address(this))).splitFees();
        IERC20(token).transfer(splitFees, amount);
    }

}

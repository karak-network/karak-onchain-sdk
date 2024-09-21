// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../src/interfaces/IKarakBaseVault.sol";

abstract contract MockVaults is Test {
    mapping(address => uint256) assetSupplyMap;
    mapping(address => uint256) totalSupplyMap;
    mapping(address => address) assetMap;

    function initVault(address vault, address asset) public {
        assetMap[vault] = asset;
        vm.mockCall(vault, abi.encodeCall(IKarakBaseVault.asset, ()), abi.encode(assetMap[vault]));
    }

    function deposit(address vault, uint256 amount) public {
        require(assetMap[vault] != address(0), "Uninitialize vault");
        assetSupplyMap[vault] += amount;
        totalSupplyMap[vault] += amount;
        vm.mockCall(vault, abi.encodeCall(IERC20.totalSupply, ()), abi.encode(totalSupplyMap[vault]));
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import "forge-std/console.sol";
import "./interfaces/IVault.sol";
import "@openzeppelin/interfaces/IERC20.sol";
import "@chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";


library OperatorStakeNormalized {

    function totalStakeNormalizedToETH(address[] calldata operators, address[] calldata vaults, address[] calldata pricefeeds)
        external
        returns (uint256 totalStakeInETH)
    {
        for (uint256 i = 0; i < operators.length; i++) {
            totalStakeStakeInETH += operatorNormalizedStakeToETH(operator[i], vaults, pricefeeds);
        }
    }

    function operatorNormalizedStakeToETH(address operator, address[] calldata vaults, address[] calldata pricefeeds)
        external
        returns (uint256 totalNormalizedStake)
    {
        for (uint256 i = 0; i < vaults.length; i++) {
            IVault vault = IVault(vault[i]);
            uint256 vaultAcitveAssets = vault.totalSupply() - IERC20(vault.asset()).balanceOf(address(vault));
            uint256 vaultValueInETH = getNormalizedPrice(pricefeeds[i], vaultAcitveAssets);
            totalNormalizedStake += vaultValueInETH;
        }
    }

    function totalStakeNormalizedToETH(address[] calldata operators, address[] calldata vaults, address calldata pricefeed)
        external
        returns (uint256 totalStakeInETH)
    {
        for (uint256 i = 0; i < operators.length; i++) {
            totalStakeStakeInETH += operatorNormalizedStakeToETH(operator[i], vaults, pricefeed);
        }
    }

    function operatorNormalizedStakeToETH(address operator, address[] calldata vaults, address calldata pricefeed)
        external
        returns (uint256 totalNormalizedStake)
    {
        for (uint256 i = 0; i < vaults.length; i++) {
            IVault vault = IVault(vault[i]);
            uint256 vaultAcitveAssets = vault.totalSupply() - IERC20(vault.asset()).balanceOf(address(vault));
            uint256 vaultValueInETH = getNormalizedPrice(pricefeed, vaultAcitveAssets);
            totalNormalizedStake += vaultValueInETH;
        }
    }

    function getNormalizedPrice(address priceFeedAddress, uint256 tokenAmount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
        (
            /* uint80 roundID */,
            int price,
            /* uint startedAt */,
            /* uint timeStamp */,
            /* uint80 answeredInRound */
        ) = priceFeed.latestRoundData();
        if (price <=0 ) revert InvalidPrice();

        uint8 decimals = priceFeed.decimals();
        
        return (tokenAmount * uint256(price)) / (10**decimals);
    }

    error InvalidPrice();
}

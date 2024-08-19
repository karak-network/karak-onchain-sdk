// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import "forge-std/console.sol";
import "./interfaces/IVault.sol";
import "@openzeppelin/interfaces/IERC20.sol";
import "@chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";


library OperatorStakeNormalized {

    ///@notice normalizes an array of operators stake according to the pricefeeds provided
    ///@param operators: list of all operators to use for normalization
    ///@param vaults: list of all vaults that are accepatble to the DSS
    ///@param pricefeeds: list of pricefeeds which should be 1:1 with the vault
    function totalStakeNormalized(address[] calldata operators, address[] calldata vaults, address[] calldata pricefeeds)
        external
        returns (uint256 totalStakeInETH)
    {
        for (uint256 i = 0; i < operators.length; i++) {
            totalStakeStakeInETH += operatorNormalizedStakeToETH(operator[i], vaults, pricefeeds);
        }
    }

    ///@notice normalizes an array of operators stake according to the pricefeed provided
    ///@param operators: list of all operators to use for normalization
    ///@param vaults: list of all vaults that are accepatble to the DSS
    ///@param pricefeed: price to be used for all vaults
    function totalStakeNormalized(address[] calldata operators, address[] calldata vaults, address calldata pricefeed)
        external
        returns (uint256 totalStakeInETH)
    {
        for (uint256 i = 0; i < operators.length; i++) {
            totalStakeStakeInETH += operatorNormalizedStakeToETH(operator[i], vaults, pricefeed);
        }
    }

    ///@notice normalizes operator stake according to the pricefeeds provided
    ///@param operators: list of all operators to use for normalization
    ///@param vaults: list of all vaults that are accepatble to the DSS
    ///@param pricefeed: price to be used for all vaults 
    function operatorNormalizedStake(address operator, address[] calldata vaults, address[] calldata pricefeeds)
       internal 
        returns (uint256 totalNormalizedStake)
    {
        for (uint256 i = 0; i < vaults.length; i++) {
            IVault vault = IVault(vault[i]);
            uint256 vaultAcitveAssets = vault.totalSupply() - IERC20(vault.asset()).balanceOf(address(vault));
            uint256 vaultValueInETH = getNormalizedPrice(pricefeeds[i], vaultAcitveAssets);
            totalNormalizedStake += vaultValueInETH;
        }
    }

    ///@notice normalizes operator stake according to the pricefeed provided
    ///@param operators: list of all operators to use for normalization
    ///@param vaults: list of all vaults that are accepatble to the DSS
    ///@param pricefeed: price to be used for all vaults 
    function operatorNormalizedStake(address operator, address[] calldata vaults, address calldata pricefeed)
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

    ///@notice retrieves price using an oracle: using chainlink's aggregatorV3Interface
    ///@param priceFeedAddress: address of the pricefeed to be used
    ///@param tokenAmount: amount to be converted
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

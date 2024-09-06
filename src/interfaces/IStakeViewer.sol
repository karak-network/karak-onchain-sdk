// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

interface IStakeViewer {
    struct StakeComponent {
        address erc20;
        uint256 balance;
        uint256 usdValue;
    }

    struct StakeDistribution {
        uint256 totalUsdValue;
        uint256 pctOfGlobalUSD;
        StakeComponent[] components;
    }

    function getTotalStakeUSD(
        address dss,
        bytes calldata oracleSpecificData // arbitrary data that the oracle needs (eg: pull data for redstone)
    ) external view returns (uint256);

    function getStakeDistributionUSD(
        address dss,
        bytes calldata oracleSpecificData
    ) external view returns (StakeDistribution memory);

    function getStakeDistributionUSDForOperators(
        address dss,
        address[] calldata operators,
        bytes calldata oracleSpecificData
    ) external view returns (StakeDistribution[] memory);
}

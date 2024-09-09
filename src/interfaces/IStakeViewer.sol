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

    function getStakeDistributionUSDForOperators(
        address dss,
        address[] calldata operators,
        bytes calldata oracleSpecificData
    ) external view returns (StakeDistribution[] memory);
}

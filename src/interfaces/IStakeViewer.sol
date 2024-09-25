// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

interface IStakeViewer {
    struct StakeComponent {
        address erc20;
        address vault;
        uint256 balance;
        uint256 usdValue;
    }

    struct OperatorStake {
        address operator;
        uint256 totalUsdValue;
        StakeComponent[] components;
    }

    struct StakeDistribution {
        uint256 globalUsdValue;
        OperatorStake[] operators;
    }

    function getStakeDistributionUSDForOperators(
        address dss,
        address[] calldata operators,
        bytes calldata oracleSpecificData
    ) external view returns (StakeDistribution memory);
}

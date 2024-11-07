// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

contract MockOracle {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, 2e6, block.timestamp, block.timestamp, 1);
    }

    function decimals() external view returns (uint8) {
        return 6;
    }
}

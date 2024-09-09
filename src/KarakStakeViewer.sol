// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import "@openzeppelin/access/Ownable.sol";
import "@chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import "./interfaces/IStakeViewer.sol";

enum OracleType {
    None,
    Chainlink
}

struct ChainlinkOracle {
    AggregatorV3Interface dataFeedAggregator;
}

struct Oracle {
    OracleType oracleType;
    bytes oracle;
}

contract KarakStakeViewer is IStakeViewer, Ownable {
    // TODO: Add upgradeability

    /* STORAGE */

    mapping(address => Oracle) public erc20ToOracle;

    /* CONSTRUCTOR */

    constructor(address initialOwner) Ownable(initialOwner) {}

    /* EXTERNAL */

    function setOracle(
        address erc20,
        Oracle calldata oracle
    ) external onlyOwner {
        erc20ToOracle[erc20] = oracle;
    }

    function getStakeDistributionUSDForOperators(
        address dss,
        address[] calldata operators,
        bytes calldata oracleSpecificData
    ) external view returns (IStakeViewer.StakeDistribution[] memory) {
        // NOTE: This is doable since core exposes a way to get the vaults for a given (DSS, operator) pair
        // TODO
    }

    /* INTERNAL */

    // TODO
}

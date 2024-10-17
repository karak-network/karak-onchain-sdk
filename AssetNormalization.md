
# KarakStakeViewer

The `KarakStakeViewer` contract is designed to provide stake distribution information in USD for operators within a decentralized staking system. It integrates oracles to fetch asset prices for converting stake values into USD.
## Configuration:
- The owner must configure the oracle data for each asset using the `setOracle()` function.
- Currently, only Chainlink oracles are supported.

## Usage:
- The `getStakeDistributionUSDForOperators` function calculates the USD value of the requested operators' active stakes across staked vaults. It iterates through the supplied list of operators, retrieves their active vaults (vaults not queued for unstaking), and identifies the active tokens in each vault (tokens not queued for withdrawal). The function then converts the vault's active token balances into USD using the associated oracle.
### Example:
1. Deploy the karakStakeViewer using a proxy.
2. Initialize the contract with owner, core's address.
    ```solidity
    karakStakeViewerProxy.initialize(ownerAddress, coreAddress);
    ```
3. Set the oracle data for each asset.
```solidity
    // caller must be owner
    Oracle memory oracle;
    oracle.oracleType = OracleType.Chainlink;
    oracle.maxStaleness = 3600; // 1 hour staleness
    oracle.oracle = abi.encode(ChainlinkOracle(chainlinkAggregatorAddress));
    karakStakeViewerProxy.setOracle(tokenAddress, oracle);
```
4. Fetching Stake Distribution for a Set of Operators
```solidity
    address[] memory operators = new address[](2);
    operators[0] = operator1;
    operators[1] = operator2;

    IStakeViewer.StakeDistribution memory distribution = karakStakeViewerProxy.getStakeDistributionUSDForOperators(dssAddress, operators, "");

``` 
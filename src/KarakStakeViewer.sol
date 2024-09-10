// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import "@chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interfaces/IStakeViewer.sol";
import "./interfaces/IKarakBaseVault.sol";
import "./interfaces/ICore.sol";

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

uint8 constant USD_DECIMALS = 8;

error UnsupportedOracleType();

contract KarakStakeViewer is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    IStakeViewer
{
    /* STORAGE */

    ICore public core;

    mapping(address => Oracle) public erc20ToOracle;

    /* CONSTRUCTOR */

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, ICore _core) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        core = _core;
    }

    /* EXTERNAL */

    function setOracle(
        address erc20,
        Oracle calldata oracle
    ) external onlyOwner {
        erc20ToOracle[erc20] = oracle;
    }

    // TODO: Gas optimize after testing for functionality
    function getStakeDistributionUSDForOperators(
        address dss,
        address[] calldata operators,
        bytes calldata oracleSpecificData
    ) external view returns (IStakeViewer.StakeDistribution memory) {
        IStakeViewer.StakeDistribution memory stakeDistribution;
        stakeDistribution.globalUsdValue = 0;
        stakeDistribution.operators = new IStakeViewer.OperatorStake[](
            operators.length
        );

        for (uint256 i = 0; i < operators.length; i++) {
            stakeDistribution.operators[i].operator = operators[i];

            address[] memory vaults = core.fetchVaultsStakedInDSS(
                operators[i],
                IDSS(dss)
            );

            if (vaults.length == 0) {
                continue;
            }

            stakeDistribution
                .operators[i]
                .components = new IStakeViewer.StakeComponent[](vaults.length);

            uint256 operatorUsdValue = 0;

            for (uint256 j = 0; j < vaults.length; j++) {
                address asset = IKarakBaseVault(vaults[j]).asset();
                uint256 assetBalance = IERC20Metadata(asset).balanceOf(
                    vaults[j]
                );
                uint256 assetUsdValue = convertToUSD(
                    asset,
                    assetBalance,
                    oracleSpecificData
                );

                stakeDistribution.operators[i].components[j].erc20 = asset;
                stakeDistribution
                    .operators[i]
                    .components[j]
                    .balance = assetBalance;
                stakeDistribution
                    .operators[i]
                    .components[j]
                    .usdValue = assetUsdValue;

                operatorUsdValue += assetUsdValue;
            }

            stakeDistribution.operators[i].totalUsdValue = operatorUsdValue;

            stakeDistribution.globalUsdValue += operatorUsdValue;
        }

        return stakeDistribution;
    }

    /* INTERNAL */

    function convertToUSD(
        address token,
        uint256 amount,
        bytes calldata oracleSpecificData
    ) internal view returns (uint256) {
        Oracle memory oracle = erc20ToOracle[token];

        if (oracle.oracleType == OracleType.Chainlink) {
            ChainlinkOracle memory chainlinkOracle = abi.decode(
                oracle.oracle,
                (ChainlinkOracle)
            );

            // TODO: Add checks and balances here to ensure the oracle and oracle data is valid

            (, int256 assetPrice, , , ) = chainlinkOracle
                .dataFeedAggregator
                .latestRoundData();

            uint8 assetDecimals = IERC20Metadata(token).decimals();

            uint8 oracleDecimals = chainlinkOracle
                .dataFeedAggregator
                .decimals();

            // TODO: Is this the right way to convert to USD?
            // convertToUSD(10 USDC) = (10e6 USDC.raw * 1e8 USD.raw) / 1e6 = 10e8 USD.raw = 10 USD
            // convertToUSD(1 ETH) = (1e18 ETH.raw * 2000e8 USD.raw) / 1e18 = 2000e8 USD.raw = 2000 USD
            // So, we can do: convertToUSD(10 USDC) + convertToUSD(1 ETH) = 10 USD + 2000 USD = 2010 USD

            uint256 oracleUsdValue = (amount * uint256(assetPrice)) /
                (10 ** assetDecimals);

            uint256 normalizedUsdValue;

            if (oracleDecimals > USD_DECIMALS) {
                normalizedUsdValue =
                    oracleUsdValue /
                    (10 ** (oracleDecimals - USD_DECIMALS));
            } else {
                normalizedUsdValue =
                    oracleUsdValue *
                    (10 ** (USD_DECIMALS - oracleDecimals));
            }

            return normalizedUsdValue;
        }

        // Add more oracle types here if needed

        revert UnsupportedOracleType();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}

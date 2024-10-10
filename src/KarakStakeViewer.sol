// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import "@chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interfaces/IStakeViewer.sol";
import "./interfaces/IKarakBaseVault.sol";
import "./interfaces/ICore.sol";
import "./interfaces/IBaseDSS.sol";

enum OracleType {
    None,
    Chainlink
}

struct ChainlinkOracle {
    AggregatorV3Interface dataFeedAggregator;
}

struct Oracle {
    OracleType oracleType;
    uint256 maxStaleness; // Max delay in seconds before oracle data is considered stale
    bytes oracle;
}

uint8 constant USD_DECIMALS = 8;

contract KarakStakeViewer is Initializable, OwnableUpgradeable, IStakeViewer {
    string public constant VERSION = "1.0.0";

    // keccak256(abi.encode(uint256(keccak256("KarakStakeViewer.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal constant STORAGE_SLOT = 0x74a1c1ab07dcbc734f35890c979db16e8a2873322b1ed7b823ac27aedd593500;

    /* STORAGE */

    struct State {
        ICore core;
        mapping(address => Oracle) tokenToOracle;
    }

    function _state() internal pure returns (State storage $) {
        assembly {
            $.slot := STORAGE_SLOT
        }
    }

    /* CONSTRUCTOR */

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, ICore core) public initializer {
        __Ownable_init(initialOwner);
        _state().core = core;
    }

    /* EXTERNAL */

    function setOracle(address token, Oracle calldata oracle) external onlyOwner {
        _state().tokenToOracle[token] = oracle;
    }

    // TODO: Gas optimize after testing for functionality
    function getStakeDistributionUSDForOperators(
        address dss,
        address[] calldata operators,
        bytes calldata oracleSpecificData
    ) external view returns (IStakeViewer.StakeDistribution memory) {
        IStakeViewer.StakeDistribution memory stakeDistribution;
        stakeDistribution.globalUsdValue = 0;
        stakeDistribution.operators = new IStakeViewer.OperatorStake[](operators.length);

        for (uint256 i = 0; i < operators.length; i++) {
            stakeDistribution.operators[i].operator = operators[i];

            // TODO: Account for entire Vaults being unstaked
            address[] memory vaults = IBaseDSS(dss).getActiveVaults(operators[i]);

            if (vaults.length == 0) {
                continue;
            }

            stakeDistribution.operators[i].components = new IStakeViewer.StakeComponent[](vaults.length);

            uint256 operatorUsdValue = 0;

            for (uint256 j = 0; j < vaults.length; j++) {
                address asset = IKarakBaseVault(vaults[j]).asset();

                uint256 sharesNotQueuedForWithdrawal =
                    IERC20Metadata(vaults[j]).totalSupply() - IERC20Metadata(vaults[j]).balanceOf(vaults[j]);
                uint256 assetBalance = IERC4626(vaults[j]).convertToAssets(sharesNotQueuedForWithdrawal);

                uint256 assetUsdValue = convertToUSD(asset, assetBalance, oracleSpecificData);

                stakeDistribution.operators[i].components[j].erc20 = asset;
                stakeDistribution.operators[i].components[j].vault = vaults[j];
                stakeDistribution.operators[i].components[j].balance = assetBalance;
                stakeDistribution.operators[i].components[j].usdValue = assetUsdValue;

                operatorUsdValue += assetUsdValue;
            }

            stakeDistribution.operators[i].totalUsdValue = operatorUsdValue;

            stakeDistribution.globalUsdValue += operatorUsdValue;
        }

        return stakeDistribution;
    }

    /* INTERNAL */

    function convertToUSD(address token, uint256 amount, bytes calldata oracleSpecificData)
        internal
        view
        returns (uint256)
    {
        State storage self = _state();
        Oracle memory oracle = self.tokenToOracle[token];

        if (oracle.oracleType == OracleType.Chainlink) {
            ChainlinkOracle memory chainlinkOracle = abi.decode(oracle.oracle, (ChainlinkOracle));

            // TODO: Add checks and balances here to ensure the oracle and oracle data is valid

            (uint80 roundId, int256 assetPrice,, uint256 updatedAt,) =
                chainlinkOracle.dataFeedAggregator.latestRoundData();

            if (assetPrice <= 0) revert InvalidAssetPrice(address(chainlinkOracle.dataFeedAggregator), roundId);
            uint256 staleness = block.timestamp - updatedAt;
            if (staleness > oracle.maxStaleness) {
                revert StaleAssetPrice(address(chainlinkOracle.dataFeedAggregator), staleness, oracle.maxStaleness);
            }

            uint8 assetDecimals = IERC20Metadata(token).decimals();

            uint8 oracleDecimals = chainlinkOracle.dataFeedAggregator.decimals();

            // TODO: Is this the right way to convert to USD?
            // convertToUSD(10 USDC) = (10e6 USDC.raw * 1e8 USD.raw) / 1e6 = 10e8 USD.raw = 10 USD
            // convertToUSD(1 ETH) = (1e18 ETH.raw * 2000e8 USD.raw) / 1e18 = 2000e8 USD.raw = 2000 USD
            // So, we can do: convertToUSD(10 USDC) + convertToUSD(1 ETH) = 10 USD + 2000 USD = 2010 USD

            uint256 oracleUsdValue = (amount * uint256(assetPrice)) / (10 ** assetDecimals);

            uint256 normalizedUsdValue;

            if (oracleDecimals > USD_DECIMALS) {
                normalizedUsdValue = oracleUsdValue / (10 ** (oracleDecimals - USD_DECIMALS));
            } else {
                normalizedUsdValue = oracleUsdValue * (10 ** (USD_DECIMALS - oracleDecimals));
            }

            return normalizedUsdValue;
        }

        // Add more oracle types here if needed

        revert UnsupportedOracleType();
    }

    /* =============== ERRORS =============== */
    error UnsupportedOracleType();
    error InvalidAssetPrice(address feed, uint80 rountId);
    error StaleAssetPrice(address feed, uint256 staleness, uint256 maxStaleness);
}

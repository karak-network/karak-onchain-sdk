// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "../helpers/Utils.sol";
import "../helpers/OperatorHelper.sol";
import "../helpers/VaultMock.sol";

import "../../src/KarakStakeViewer.sol";

contract KarakStakeViewerTest is OperatorHelper, MockVaults {
    KarakStakeViewer karakStakeViewer;
    AggregatorV3Interface dataFeedAggregator;
    TestDSS dss;
    address proxyOwner;
    address owner;
    address token;
    uint256 maxSlashablePercentageWad = 30 * (10 ** 18);
    uint256 DEPOSIT_LIMIT = 1e50 + 7;
    uint256 assetToUSD = 2e6;
    uint8 priceFeedDecimals = 6;
    uint8 tokenDecimal = 6;
    mapping(address => IStakeViewer.StakeComponent) expectedVaultStakeData;
    mapping(address => uint256) expectedOperatorTotalUsdValue;
    uint256 expectedGlobalUSDValue;

    function setUp() public {
        dataFeedAggregator = AggregatorV3Interface(vm.randomAddress());
        proxyOwner = vm.randomAddress();
        owner = vm.randomAddress();
        token = vm.randomAddress();
        karakStakeViewer = KarakStakeViewer(CommonUtils.deployProxy(proxyOwner, address(new KarakStakeViewer()), ""));
        karakStakeViewer.initialize(owner, ICore(core));
        vm.prank(owner);
        karakStakeViewer.setOracle(
            token,
            Oracle({
                oracleType: OracleType.Chainlink,
                oracle: abi.encode(ChainlinkOracle({dataFeedAggregator: dataFeedAggregator}))
            })
        );
        vm.mockCall(core, abi.encodeCall(ICore.registerDSS, maxSlashablePercentageWad), "");
        dss = TestDSS(CommonUtils.deployProxy(proxyOwner, address(new TestDSS()), ""));
        dss.initialize(core, maxSlashablePercentageWad);

        // mock oracle data
        vm.mockCall(
            address(dataFeedAggregator),
            abi.encodeCall(AggregatorV3Interface.latestRoundData, ()),
            abi.encode(uint80(0), int256(assetToUSD), uint256(0), uint256(0), uint80(0))
        );
        vm.mockCall(
            address(dataFeedAggregator),
            abi.encodeCall(AggregatorV3Interface.decimals, ()),
            abi.encode(priceFeedDecimals)
        );

        // mock token data
        vm.mockCall(token, abi.encodeCall(IERC20Metadata.decimals, ()), abi.encode(tokenDecimal));
    }

    function test_stake_value(uint256 depositAmount, uint256 vaultSharesForWithdrawal) public {
        address vault = vm.randomAddress();
        address operator = vm.randomAddress();
        registerStakeAndDeposit(operator, vault, depositAmount, vaultSharesForWithdrawal);

        address[] memory operators = new address[](1);
        operators[0] = operator;
        IStakeViewer.StakeDistribution memory result =
            karakStakeViewer.getStakeDistributionUSDForOperators(address(dss), operators, "");
        validateStakeDistribution(result);
    }

    function test_stake_value_multiple_vault(uint256 numOfVaults) public {
        address operator = vm.randomAddress();
        registerStakeAndDepositMultipleVaults(numOfVaults, operator);
        address[] memory operators = new address[](1);
        operators[0] = operator;
        IStakeViewer.StakeDistribution memory result =
            karakStakeViewer.getStakeDistributionUSDForOperators(address(dss), operators, "");
        validateStakeDistribution(result);
    }

    function test_stake_value_multiple_vault_mutiple_operators(uint256 numOfOperators) public {
        numOfOperators %= OPERATOR_LIMIT;
        vm.assume(numOfOperators > 0);
        address[] memory operators = generateNAddresses(numOfOperators);
        for (uint256 i = 0; i < operators.length; i++) {
            uint256 numOfVaults = vm.randomUint();
            registerStakeAndDepositMultipleVaults(numOfVaults, operators[i]);
        }
        IStakeViewer.StakeDistribution memory result =
            karakStakeViewer.getStakeDistributionUSDForOperators(address(dss), operators, "");
        validateStakeDistribution(result);
    }

    function registerStakeAndDeposit(
        address operator,
        address vault,
        uint256 depositAmount,
        uint256 vaultSharesForWithdrawal
    ) public {
        depositAmount %= DEPOSIT_LIMIT;
        vm.assume(depositAmount > 0);
        vaultSharesForWithdrawal %= depositAmount;
        initVault(vault, token);
        registerOperator(operator, dss);
        deposit(vault, depositAmount);
        updateVaultStakeIntoDSS(operator, dss, vault, true);

        // mock balance of vault token
        mockVaultSharesBalance(vault, vault, vaultSharesForWithdrawal);
        mockConvertToAssets(vault, depositAmount - vaultSharesForWithdrawal);
        updateVaultStakeComponent(vault, operator, depositAmount - vaultSharesForWithdrawal);
    }

    function registerStakeAndDepositMultipleVaults(uint256 numOfVaults, address operator) public {
        numOfVaults %= VAULT_LIMIT;
        vm.assume(numOfVaults > 0);
        address[] memory vaults = generateNAddresses(numOfVaults);
        for (uint256 i = 0; i < vaults.length; i++) {
            uint256 depositAmount = vm.randomUint();
            uint256 assetsMarkedForWithdrawal = vm.randomUint();
            registerStakeAndDeposit(operator, vaults[i], depositAmount, assetsMarkedForWithdrawal);
        }
    }

    function mockVaultSharesBalance(address vault, address user, uint256 shares) public {
        vm.mockCall(vault, abi.encodeCall(IERC20.balanceOf, (user)), abi.encode(shares));
    }

    function mockConvertToAssets(address vault, uint256 shares) public {
        vm.mockCall(vault, abi.encodeCall(IERC4626.convertToAssets, (shares)), abi.encode(shares));
    }

    function updateVaultStakeComponent(address vault, address operator, uint256 balance) public returns (uint256) {
        expectedVaultStakeData[vault].erc20 = token;
        expectedVaultStakeData[vault].vault = vault;
        expectedVaultStakeData[vault].balance = balance;
        expectedVaultStakeData[vault].usdValue = convertTokenToUSD(balance);
        expectedOperatorTotalUsdValue[operator] += expectedVaultStakeData[vault].usdValue;
        expectedGlobalUSDValue += expectedVaultStakeData[vault].usdValue;
        return expectedVaultStakeData[vault].usdValue;
    }

    function convertTokenToUSD(uint256 value) public view returns (uint256) {
        return ((value * assetToUSD) * (10 ** USD_DECIMALS)) / ((10 ** priceFeedDecimals) * (10 ** tokenDecimal));
    }

    function validateStakeDistribution(IStakeViewer.StakeDistribution memory computedData) public view {
        assertEq(computedData.globalUsdValue, expectedGlobalUSDValue);
        for (uint256 i = 0; i < computedData.operators.length; i++) {
            assertEq(
                expectedOperatorTotalUsdValue[computedData.operators[i].operator],
                computedData.operators[i].totalUsdValue
            );
            for (uint256 j = 0; j < computedData.operators[i].components.length; j++) {
                assertEq(
                    keccak256(abi.encode(computedData.operators[i].components[j])),
                    keccak256(abi.encode(expectedVaultStakeData[computedData.operators[i].components[j].vault]))
                );
            }
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../helpers/OperatorHelper.sol";
import "../../src/interfaces/ICore.sol";
import "../helpers/Utils.sol";

contract BaseDSSTest is OperatorHelper {
    using CommonUtils for address[];

    IBaseDSS dss;
    uint256 maxSlashablePercentageWad = 30 * (10 ** 18);

    // Upper limit to operator count
    uint256 internal constant OPERATOR_LIMIT = 113;
    uint256 internal constant VAULT_LIMIT = 32;

    function setUp() public {
        vm.mockCall(core, abi.encodeCall(ICore.registerDSS, maxSlashablePercentageWad), "");
        dss = IBaseDSS(address(new TestDSS(core, maxSlashablePercentageWad)));
    }

    function test_registration(uint256 operatorCount) public {
        // limiting to OPERATOR_LIMIT operators
        operatorCount %= OPERATOR_LIMIT;
        vm.assume(operatorCount != 0);
        address[] memory operators = generateNAddresses(operatorCount);
        registerOperators(operators, dss);
        address[] memory operatorsRegistered = dss.getRegisteredOperators();
        operators.assertEq(operatorsRegistered);
    }

    function test_fail_registration(uint256 operatorCount) public {
        // limiting to OPERATOR_LIMIT operators
        operatorCount %= OPERATOR_LIMIT;
        vm.assume(operatorCount != 0);
        address[] memory operators = generateNAddresses(operatorCount);
        registerOperators(operators, dss);
        address[] memory operatorsRegistered = dss.getRegisteredOperators();
        operators[0] = address(1);
        vm.expectRevert(CommonUtils.UnequalArrays.selector);
        operators.assertEq(operatorsRegistered);
    }

    function test_unregistration(uint256 operatorCount, uint256 unregisterOperatorsCount) public {
        // limiting to OPERATOR_LIMIT operators
        operatorCount %= OPERATOR_LIMIT;
        vm.assume(operatorCount != 0);
        unregisterOperatorsCount %= operatorCount;
        test_registration(operatorCount);
        address[] memory operators = dss.getRegisteredOperators();
        address[] memory unregisteredOperators = new address[](unregisterOperatorsCount);
        address[] memory expectedOperators = new address[](operatorCount - unregisterOperatorsCount);
        for (uint256 i = 0; i < expectedOperators.length; i++) {
            expectedOperators[i] = operators[i];
        }
        for (uint256 i = expectedOperators.length; i < operatorCount; i++) {
            unregisteredOperators[i - expectedOperators.length] = operators[i];
        }
        unregisterOperators(unregisteredOperators, dss);
        dss.getRegisteredOperators().assertEq(expectedOperators);
    }

    function test_stake_vault(address operator, address vault) public {
        vm.assume(vault != address(0) && operator != address(0));
        requestVaultStakeUpdateRequest(operator, dss, vault, true);
        // vault isn't added in the state when staking in requested
        dss.getVaultsNotQueuedForUnstaking(operator).assertEq(new address[](0));

        completeVaultStakeUpdateRequest(operator, dss, vault, true);
        address[] memory expectedVaults = new address[](1);
        expectedVaults[0] = vault;
        // vault gets added in the state when staking in completed
        dss.getVaultsNotQueuedForUnstaking(operator).assertEq(expectedVaults);

        // testing random address should give zero result
        address newOperator = vm.randomAddress();

        dss.getVaultsNotQueuedForUnstaking(newOperator).assertEq(new address[](0));
    }

    function test_stake_vault_in_multiple_operators(uint256 numOfOperators) public {
        numOfOperators %= OPERATOR_LIMIT;
        numOfOperators++;
        address[] memory operators = generateNAddresses(numOfOperators);
        address[] memory vaults = generateNAddresses(numOfOperators);
        for (uint256 i = 0; i < operators.length; i++) {
            test_stake_vault(operators[i], vaults[i]);
        }
    }

    function test_stake_multiple_vaults(address operator, uint256 numofVaults) public {
        numofVaults %= VAULT_LIMIT;
        numofVaults++;
        address[] memory vaults = generateNAddresses(numofVaults);
        for (uint256 i = 0; i < vaults.length; i++) {
            updateVaultStakeIntoDSS(operator, dss, vaults[i], true);
        }
        vaults.assertEq(dss.getVaultsNotQueuedForUnstaking(operator));
    }

    function test_multiple_operators_multiple_vaults(uint256 numOfOperators, uint256 numOfVaults) public {
        numOfOperators %= OPERATOR_LIMIT;
        numOfVaults %= VAULT_LIMIT;
        numOfOperators++;
        numOfVaults++;
        address[] memory operators = generateNAddresses(numOfOperators);
        for (uint256 i = 0; i < operators.length; i++) {
            test_stake_multiple_vaults(operators[i], numOfVaults);
        }
    }

    function test_unstake_vault(address operator, address vault) internal {
        vm.assume(operator != address(0) && vault != address(0));
        updateVaultStakeIntoDSS(operator, dss, vault, true);
        address[] memory expectedResult = new address[](1);
        expectedResult[0] = vault;
        dss.getVaultsNotQueuedForUnstaking(operator).assertEq(expectedResult);

        // initiate request to unstake vault
        requestVaultStakeUpdateRequest(operator, dss, vault, false);
        expectedResult = new address[](0);
        dss.getVaultsNotQueuedForUnstaking(operator).assertEq(expectedResult);
    }

    function test_unstake_subset_of_staked_vault(
        address operator,
        uint256 numOfStakedVaults,
        uint256 numOfUnstakedVaults
    ) public {
        numOfStakedVaults %= VAULT_LIMIT;
        numOfStakedVaults++;
        numOfUnstakedVaults %= numOfStakedVaults;

        address[] memory stakedVaults = generateNAddresses(numOfStakedVaults);
        updateMultipleVaultsStakeIntoDSS(operator, dss, stakedVaults, true);

        address[] memory unstakedVaults = new address[](numOfUnstakedVaults);
        address[] memory expectedResult = new address[](numOfStakedVaults - numOfUnstakedVaults);
        for (uint256 i = 0; i < numOfUnstakedVaults; i++) {
            unstakedVaults[i] = stakedVaults[i];
        }
        for (uint256 i = numOfUnstakedVaults; i < numOfStakedVaults; i++) {
            expectedResult[i - numOfUnstakedVaults] = stakedVaults[i];
        }

        for (uint256 i = 0; i < unstakedVaults.length; i++) {
            requestVaultStakeUpdateRequest(operator, dss, unstakedVaults[i], false);
        }
        dss.getVaultsNotQueuedForUnstaking(operator).assertEq(expectedResult);
    }

    function test_jailing_unjailing(address operator) public {
        vm.assume(operator != address(0));
        assertFalse(TestDSS(address(dss)).isOperatorJailed(operator));

        TestDSS(address(dss)).jailOperator(operator);
        assertTrue(TestDSS(address(dss)).isOperatorJailed(operator));

        address newOperator = vm.randomAddress();
        assertFalse(TestDSS(address(dss)).isOperatorJailed(newOperator));

        TestDSS(address(dss)).unjailOperator(operator);
        assertFalse(TestDSS(address(dss)).isOperatorJailed(operator));
    }
}

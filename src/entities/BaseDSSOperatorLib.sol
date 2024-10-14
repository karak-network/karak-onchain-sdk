// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

library BaseDSSOperatorLib {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct State {
        EnumerableSet.AddressSet vaultsNotQueuedForUnstaking;
        bool isJailed;
    }

    function addVault(State storage operatorState, address vault) internal {
        operatorState.vaultsNotQueuedForUnstaking.add(vault);
    }

    function removeVault(State storage operatorState, address vault) internal {
        if (operatorState.vaultsNotQueuedForUnstaking.contains(vault)) {
            operatorState.vaultsNotQueuedForUnstaking.remove(vault);
        }
    }

    function jailOperator(State storage operatorState) internal {
        operatorState.isJailed = true;
    }

    function unjailOperator(State storage operatorState) internal {
        operatorState.isJailed = false;
    }

    function fetchVaultsNotQueuedForWithdrawal(State storage operatorState) internal view returns (address[] memory) {
        return operatorState.vaultsNotQueuedForUnstaking.values();
    }

    function isOperatorJailed(State storage operatorState) internal view returns (bool) {
        return operatorState.isJailed;
    }
}

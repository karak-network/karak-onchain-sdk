// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {BaseDSSLib} from "./BaseDSSLib.sol";
import {Constants} from "../interfaces/Constants.sol";

library OperatorLib {
    using EnumerableSet for EnumerableSet.AddressSet;
    using BaseDSSLib for BaseDSSLib.State;

    struct State {
        EnumerableSet.AddressSet vaultsNotQueuedForUnstaking;
        bool isJailed;
    }

    function addVault(address operator, address vault) internal {
        _operatorState(operator).vaultsNotQueuedForUnstaking.add(vault);
    }

    function removeVault(address operator, address vault) internal {
        State storage operatorState = _operatorState(operator);
        if (operatorState.vaultsNotQueuedForUnstaking.contains(vault)) {
            operatorState.vaultsNotQueuedForUnstaking.remove(vault);
        }
    }

    function jailOperator(address operator) internal {
        _operatorState(operator).isJailed = true;
    }

    function unjailOperator(address operator) internal {
        _operatorState(operator).isJailed = false;
    }

    function fetchVaultsNotQueuedForWithdrawal(address operator) internal view returns (address[] memory) {
        return _operatorState(operator).vaultsNotQueuedForUnstaking.values();
    }

    function isOperatorJailed(address operator) internal view returns (bool) {
        return _operatorState(operator).isJailed;
    }

    function _operatorState(address operator) internal pure returns (State storage $) {
        bytes32 slot = keccak256(abi.encode(Constants.OPERATOR_STORAGE_PREFIX, operator));
        assembly {
            $.slot := slot
        }
    }
}

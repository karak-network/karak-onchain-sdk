// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;

import "@openzeppelin/utils/structs/EnumerableMap.sol";

library BaseDSSLib {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    struct State {
        /// @notice Mapping of operators to challengers they are enrolled in
        EnumerableMap.AddressToUintMap operatorState;
        /// @notice address of the core
        address core;
    }

    function updateOperatorMap(State storage self, address operator, bool toAdd) internal {
        if (toAdd) {
            self.operatorState.set(operator, uint256(keccak256(abi.encode(operator))));
        } else {
            if (self.operatorState.contains(operator)) self.operatorState.remove(operator);
        }
    }

    function getOperators(State storage self) internal view returns (address[] memory operators) {
        operators = self.operatorState.keys();
    }

    function init(State storage self, address _core) internal {
        self.core = _core;
    }
}

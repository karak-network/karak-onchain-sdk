// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;

import "@openzeppelin/utils/structs/EnumerableMap.sol";
import "../interfaces/ICore.sol";

library BaseDSSLib {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    struct State {
        /// @notice Mapping of operators to challengers they are enrolled in
        EnumerableMap.AddressToUintMap operatorState;
        /// @notice address of the core
        ICore core;
    }

    function addOperator(State storage self, address operator) internal {
        self.operatorState.set(operator, uint256(keccak256(abi.encode(operator))));
    }

    function removeOperator(State storage self, address operator) internal {
        if (self.operatorState.contains(operator)) self.operatorState.remove(operator);
    }

    function getOperators(State storage self) internal view returns (address[] memory operators) {
        operators = self.operatorState.keys();
    }

    function init(State storage self, address _core, uint256 maxSlashablePercentageWad) internal {
        self.core = ICore(_core);
        ICore(_core).registerDSS(maxSlashablePercentageWad);
    }
}

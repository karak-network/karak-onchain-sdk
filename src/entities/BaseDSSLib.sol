// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/ICore.sol";

library BaseDSSLib {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct State {
        /// @notice Set of operators registered with DSS
        EnumerableSet.AddressSet operatorState;
        /// @notice address of the core
        ICore core;
    }

    function addOperator(State storage self, address operator) internal {
        self.operatorState.add(operator);
    }

    function removeOperator(State storage self, address operator) internal {
        if (self.operatorState.contains(operator)) self.operatorState.remove(operator);
    }

    function getOperators(State storage self) internal view returns (address[] memory operators) {
        operators = self.operatorState.values();
    }

    function init(State storage self, address _core, uint256 maxSlashablePercentageWad) internal {
        self.core = ICore(_core);
        ICore(_core).registerDSS(maxSlashablePercentageWad);
    }

    function isOperatorRegistered(State storage self, address operator) internal view returns (bool) {
        return self.operatorState.contains(operator);
    }
}

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/ICore.sol";

library BaseDSSLib {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct State {
        /// @notice Set of operators registered with DSS
        EnumerableSet.AddressSet operatorSet;
        /// @notice address of the core
        ICore core;
    }

    function addOperator(State storage self, address operator) internal {
        self.operatorSet.add(operator);
    }

    function removeOperator(State storage self, address operator) internal {
        if (self.operatorSet.contains(operator)) self.operatorSet.remove(operator);
    }

    function getOperators(State storage self) internal view returns (address[] memory operators) {
        operators = self.operatorSet.values();
    }

    function init(State storage self, address _core, uint256 maxSlashablePercentageWad) internal {
        self.core = ICore(_core);
        ICore(_core).registerDSS(maxSlashablePercentageWad);
    }

    function isOperatorRegistered(State storage self, address operator) internal view returns (bool) {
        return self.operatorSet.contains(operator);
    }
}

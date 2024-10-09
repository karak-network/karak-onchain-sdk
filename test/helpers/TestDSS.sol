// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;

import "../../src/BaseDSS.sol";

contract TestDSS is BaseDSS {
    using BaseDSSOperatorLib for BaseDSSOperatorLib.State;

    function initialize(address core, uint256 maxSlashablePercentageWad) public {
        _init(core, maxSlashablePercentageWad);
    }

    function jailOperator(address operator) public {
        _jailOperator(operator);
    }

    function unjailOperator(address operator) public {
        _unjailOperator(operator);
    }

    function isOperatorJailed(address operator) public view override returns (bool) {
        return _baseDssOperatorState(operator).isOperatorJailed();
    }

    function registrationHook(address operator, bytes memory temp) public override {
        super.registrationHook(operator, temp);
    }
}

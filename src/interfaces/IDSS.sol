// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/interfaces/IERC165.sol";

interface IDSS is IERC165 {
    // HOOKS
    function registrationHook(address operator, bytes memory extraData) external;
    function unregistrationHook(address operator) external;
    function getRegisteredOperators() external returns (address[] memory);

    error CallerNotCore();
}

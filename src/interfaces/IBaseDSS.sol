// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/interfaces/IERC165.sol";

interface IBaseDSS is IERC165 {
    struct StakeUpdateRequest {
        address vault;
        IBaseDSS dss;
        bool toStake; // true for stake, false for unstake
    }

    struct QueuedStakeUpdate {
        uint48 nonce;
        uint48 startTimestamp;
        address operator;
        StakeUpdateRequest updateRequest;
    }
    // HOOKS

    function registrationHook(address operator, bytes memory extraData) external;
    function unregistrationHook(address operator) external;
    function requestUpdateStakeHook(address operator, StakeUpdateRequest memory newStake) external;
    function finishUpdateStakeHook(address operator, QueuedStakeUpdate memory queuedStakeUpdate) external;

    // VIEW FUNCTIONS
    function getRegisteredOperators() external returns (address[] memory);

    error CallerNotCore();
}

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.25;

interface ICore {
    /* ========== MUTATIVE FUNCTIONS ========== */
    function registerDSS(uint256 maxSlashablePercentageWad) external;
    /* ======================================== */
}

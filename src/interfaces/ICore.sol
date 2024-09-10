// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import "./IDSS.sol";

interface ICore {
    /* ========== MUTATIVE FUNCTIONS ========== */
    function registerDSS(uint256 maxSlashablePercentageWad) external;
    /* ======================================== */

    /* ============ VIEW FUNCTIONS ============ */
    function fetchVaultsStakedInDSS(address operator, IDSS dss) external view returns (address[] memory vaults);
    /* ======================================== */
}

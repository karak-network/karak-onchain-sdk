// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import "./IBaseDSS.sol";

interface ICore {
    /* ========== MUTATIVE FUNCTIONS ========== */
    function registerDSS(uint256 maxSlashablePercentageWad) external;
    /* ======================================== */

    /* ============ VIEW FUNCTIONS ============ */
    function fetchVaultsStakedInDSS(address operator, IBaseDSS dss) external view returns (address[] memory vaults);
    /* ======================================== */
}

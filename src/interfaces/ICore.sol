// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

interface ICore {
    function fetchVaultsStakedInDSS(
        address operator,
        address dss
    ) external view returns (address[] memory vaults);
}

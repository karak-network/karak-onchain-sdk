// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;

import "forge-std/Test.sol";
import "./TestDSS.sol";

abstract contract OperatorHelper is Test {
    address core = address(11);
    uint48 nonce = 0;

    function registerOperator(address operator, IBaseDSS dss) public {
        vm.startPrank(core);
        dss.registrationHook(operator, "");
        vm.stopPrank();
    }

    function registerOperators(address[] memory operators, IBaseDSS dss) public {
        vm.startPrank(core);
        for (uint256 i = 0; i < operators.length; i++) {
            dss.registrationHook(operators[i], "");
        }
        vm.stopPrank();
    }

    function unregisterOperator(address operator, IBaseDSS dss) public {
        vm.startPrank(core);
        dss.unregistrationHook(operator);
        vm.stopPrank();
    }

    function unregisterOperators(address[] memory operators, IBaseDSS dss) public {
        vm.startPrank(core);
        for (uint256 i = 0; i < operators.length; i++) {
            dss.unregistrationHook(operators[i]);
        }
        vm.stopPrank();
    }

    function requestVaultStakeUpdateRequest(address operator, IBaseDSS dss, address vault, bool toStake) public {
        vm.startPrank(core);
        dss.requestUpdateStakeHook(
            operator, IBaseDSS.StakeUpdateRequest({vault: vault, dss: IBaseDSS(dss), toStake: toStake})
        );
        vm.stopPrank();
        nonce++;
    }

    function completeVaultStakeUpdateRequest(address operator, IBaseDSS dss, address vault, bool toStake) public {
        vm.startPrank(core);
        dss.finishUpdateStakeHook(
            operator,
            IBaseDSS.QueuedStakeUpdate({
                nonce: nonce,
                startTimestamp: uint48(block.timestamp),
                operator: operator,
                updateRequest: IBaseDSS.StakeUpdateRequest({vault: vault, dss: IBaseDSS(dss), toStake: toStake})
            })
        );
        vm.stopPrank();
        nonce++;
    }

    function updateVaultStakeIntoDSS(address operator, IBaseDSS dss, address vault, bool toStake) internal {
        vm.startPrank(core);
        toStake
            ? dss.finishUpdateStakeHook(
                operator,
                IBaseDSS.QueuedStakeUpdate({
                    nonce: nonce,
                    startTimestamp: uint48(block.timestamp),
                    operator: operator,
                    updateRequest: IBaseDSS.StakeUpdateRequest({vault: vault, dss: IBaseDSS(dss), toStake: toStake})
                })
            )
            : dss.requestUpdateStakeHook(
                operator, IBaseDSS.StakeUpdateRequest({vault: vault, dss: IBaseDSS(dss), toStake: toStake})
            );
        vm.stopPrank();
    }

    function updateMultipleVaultsStakeIntoDSS(address operator, IBaseDSS dss, address[] memory vaults, bool toStake)
        internal
    {
        vm.startPrank(core);
        for (uint256 i = 0; i < vaults.length; i++) {
            toStake
                ? dss.finishUpdateStakeHook(
                    operator,
                    IBaseDSS.QueuedStakeUpdate({
                        nonce: nonce,
                        startTimestamp: uint48(block.timestamp),
                        operator: operator,
                        updateRequest: IBaseDSS.StakeUpdateRequest({vault: vaults[i], dss: IBaseDSS(dss), toStake: toStake})
                    })
                )
                : dss.requestUpdateStakeHook(
                    operator, IBaseDSS.StakeUpdateRequest({vault: vaults[i], dss: IBaseDSS(dss), toStake: toStake})
                );
        }
        vm.stopPrank();
    }

    function generateNAddresses(uint256 num) public returns (address[] memory) {
        address[] memory addresses = new address[](num);
        for (uint256 i = 0; i < num; i++) {
            addresses[i] = vm.randomAddress();
        }
        return addresses;
    }
}

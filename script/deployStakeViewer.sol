// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.25;

import {Script, console2} from "forge-std/Script.sol";
import {KarakStakeViewer} from "../src/KarakStakeViewer.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployStakeViewer is Script {
    address internal CORE = vm.envAddress("CORE");

    function run() external {
        vm.startBroadcast();

        address stakeViewerImplementation = address(new KarakStakeViewer());
        console2.log("StakeViewer implementation deployed at: ", stakeViewerImplementation);
        console2.log();

        address stakeViewerProxy = address(new TransparentUpgradeableProxy(
            stakeViewerImplementation,
            msg.sender,
            abi.encodeWithSelector(
                KarakStakeViewer.initialize.selector,
                msg.sender,
                CORE
            )
        ));
        console2.log("StakeViewer proxy deployed at: ", stakeViewerProxy);
        console2.log();

        vm.stopBroadcast();
    }
}

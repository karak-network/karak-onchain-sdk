// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.25;

import {Script, console2} from "forge-std/Script.sol";
import "../src/KarakStakeViewer.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {MockOracle} from "../test/helpers/MockOracle.sol";

contract DeployStakeViewer is Script {
    address internal CORE = vm.envAddress("CORE");
    address internal TOKEN = vm.envAddress("TOKEN");

    function run() external {
        vm.startBroadcast();

        address stakeViewerImplementation = address(new KarakStakeViewer());
        console2.log("StakeViewer implementation deployed at: ", stakeViewerImplementation);
        console2.log();

        address stakeViewerProxy = address(
            new TransparentUpgradeableProxy(
                stakeViewerImplementation,
                msg.sender,
                abi.encodeWithSelector(KarakStakeViewer.initialize.selector, msg.sender, CORE)
            )
        );
        console2.log("StakeViewer proxy deployed at: ", stakeViewerProxy);
        console2.log();

        KarakStakeViewer stakeViewer = KarakStakeViewer(payable(stakeViewerProxy));

        MockOracle mockOracle = new MockOracle();
        Oracle memory oracle = Oracle({
            oracleType: OracleType.Chainlink,
            oracle: abi.encode(ChainlinkOracle({dataFeedAggregator: AggregatorV3Interface(address(mockOracle))})),
            maxStaleness: 10000
        });
        stakeViewer.setOracle(TOKEN, oracle);

        vm.stopBroadcast();
    }
}

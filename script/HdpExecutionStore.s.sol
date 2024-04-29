// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {IAggregatorsFactory} from "../src/interfaces/IAggregatorsFactory.sol";
import {IFactsRegistry} from "../src/interfaces/IFactsRegistry.sol";
import {HdpExecutionStore} from "../src/HdpExecutionStore.sol";

contract HdpExecutionStoreDeployer is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IFactsRegistry factsRegistry = IFactsRegistry(
            vm.envAddress("FACTS_REGISTRY_ADDRESS")
        );
        IAggregatorsFactory aggregatorsFactory = IAggregatorsFactory(
            vm.envAddress("AGGREGATORS_FACTORY_ADDRESS")
        );
        bytes32 programHash = _getProgramHash();

        // Deploy the HdpExecutionStore
        HdpExecutionStore hdpExecutionStore = new HdpExecutionStore(
            factsRegistry,
            aggregatorsFactory,
            programHash
        );

        console2.log(
            "HdpExecutionStore deployed at: ",
            address(hdpExecutionStore)
        );

        vm.stopBroadcast();
    }

    function _getProgramHash() internal returns (bytes32) {
        string[] memory inputs = new string[](5);
        inputs[0] = "python3";
        inputs[1] = "-m";
        inputs[2] = "helpers.hash_program";
        inputs[3] = "--program";
        inputs[4] = "./helpers/target/hdp.json";
        bytes memory abiEncoded = vm.ffi(inputs);
        return abi.decode(abiEncoded, (bytes32));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test} from "forge-std/Test.sol";
import {HdpExecutionStore} from "../src/HdpExecutionStore.sol";
import {BlockSampledDatalake, BlockSampledDatalakeCodecs} from "../src/datatypes/BlockSampledDatalakeCodecs.sol";
import {ComputationalTask, ComputationalTaskCodecs} from "../src/datatypes/ComputationalTaskCodecs.sol";
import {AggregateFn, Operator} from "../src/datatypes/ComputationalTaskCodecs.sol";
import {IFactsRegistry} from "../src/interfaces/IFactsRegistry.sol";
import {ISharpFactsAggregator} from "../src/interfaces/ISharpFactsAggregator.sol";
import {IAggregatorsFactory} from "../src/interfaces/IAggregatorsFactory.sol";
import {Uint256Splitter} from "../src/lib/Uint256Splitter.sol";

contract MockFactsRegistry is IFactsRegistry {
    mapping(bytes32 => bool) public isValid;

    function markValid(bytes32 fact) public {
        isValid[fact] = true;
    }
}

contract MockAggregatorsFactory is IAggregatorsFactory {
    mapping(uint256 => ISharpFactsAggregator) public aggregatorsById;

    function createAggregator(
        uint256 id,
        ISharpFactsAggregator aggregator
    ) external {
        aggregatorsById[id] = aggregator;
    }
}

contract MockSharpFactsAggregator is ISharpFactsAggregator {
    uint256 public usedMmrSize;
    bytes32 public usedMmrRoot;

    constructor(bytes32 poseidonMmrRoot, uint256 mmrSize) {
        usedMmrRoot = poseidonMmrRoot;
        usedMmrSize = mmrSize;
    }

    function aggregatorState() external view returns (AggregatorState memory) {
        return
            AggregatorState({
                poseidonMmrRoot: usedMmrRoot,
                keccakMmrRoot: bytes32(0),
                mmrSize: usedMmrSize,
                continuableParentHash: bytes32(0)
            });
    }
}

contract HdpExecutionStoreTest is Test {
    using BlockSampledDatalakeCodecs for BlockSampledDatalake;
    using ComputationalTaskCodecs for ComputationalTask;

    address public proverAddress = address(12);

    HdpExecutionStore private hdp;
    IFactsRegistry private factsRegistry;
    IAggregatorsFactory private aggregatorsFactory;
    ISharpFactsAggregator private sharpFactsAggregator;

    // Cached fetched data
    bytes32 programHash;
    uint256 fetchedMmrId;
    uint256 fetchedMmrSize;
    bytes32 fetchedMmrRoot;
    bytes32 fetchedResultsMerkleRoot;
    bytes32 fetchedTasksMerkleRoot;
    bytes32[][] fetchedResultsInclusionProofs;
    bytes32[][] fetchedTasksInclusionProofs;
    bytes32[] fetchedResults;
    bytes32[] fetchedTasksCommitments;

    function setUp() public {
        // Registery for facts that has been processed through SHARP
        factsRegistry = new MockFactsRegistry();
        // Factory for creating SHARP facts aggregators
        aggregatorsFactory = new MockAggregatorsFactory();

        // Get program hash
        programHash = _getProgramHash();
        hdp = new HdpExecutionStore(
            factsRegistry,
            aggregatorsFactory,
            programHash
        );

        // Parse from input file
        (
            fetchedMmrId,
            fetchedMmrSize,
            fetchedMmrRoot,
            fetchedResultsMerkleRoot,
            fetchedTasksMerkleRoot,
            fetchedResultsInclusionProofs,
            fetchedTasksInclusionProofs,
            fetchedResults,
            fetchedTasksCommitments
        ) = _fetchCairoInput();

        // Mock SHARP facts aggregator
        sharpFactsAggregator = new MockSharpFactsAggregator(
            fetchedMmrRoot,
            fetchedMmrSize
        );

        // Step 0. Create mock SHARP facts aggregator
        aggregatorsFactory.createAggregator(fetchedMmrId, sharpFactsAggregator);
        assertTrue(hdp.hasRole(keccak256("OPERATOR_ROLE"), address(this)));
        hdp.grantRole(keccak256("OPERATOR_ROLE"), proverAddress);
    }

    function testSingleBlockSingleBlockSampledDatalake() public {
        (uint256 taskRootLow, uint256 taskRootHigh) = Uint256Splitter.split128(
            uint256(bytes32(fetchedTasksMerkleRoot))
        );

        (uint256 resultRootLow, uint256 resultRootHigh) = Uint256Splitter
            .split128(uint256(bytes32(fetchedResultsMerkleRoot)));

        // Cache MMR root
        hdp.cacheMmrRoot(fetchedMmrId);

        // Compute fact hash from PIE
        bytes32 factHash = _computeFactHash();

        // Mark the fact as valid (Mocking SHARP behavior)
        factsRegistry.markValid(factHash);
        bool isValid = factsRegistry.isValid(factHash);
        assertEq(isValid, true);

        // Check if the request is valid in the SHARP Facts Registry
        // If valid, Store the task result
        vm.prank(proverAddress);
        hdp.authenticateTaskExecution(
            fetchedMmrId,
            fetchedMmrSize,
            uint128(resultRootLow),
            uint128(resultRootHigh),
            uint128(taskRootLow),
            uint128(taskRootHigh),
            fetchedTasksInclusionProofs,
            fetchedResultsInclusionProofs,
            fetchedResults,
            fetchedTasksCommitments
        );

        // Check if the task state is FINALIZED
        HdpExecutionStore.TaskStatus taskStatusAfter = hdp.getTaskStatus(
            fetchedTasksCommitments[0]
        );
        assertEq(
            uint256(taskStatusAfter),
            uint256(HdpExecutionStore.TaskStatus.FINALIZED)
        );

        // Check if the task result is stored
        bytes32 taskResult = hdp.getFinalizedTaskResult(
            fetchedTasksCommitments[0]
        );
        assertEq(taskResult, fetchedResults[0]);
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

    function _computeFactHash() internal returns (bytes32) {
        string[] memory inputs = new string[](5);
        inputs[0] = "python3";
        inputs[1] = "-m";
        inputs[2] = "helpers.compute_fact_hash";
        inputs[3] = "--cairo_pie";
        inputs[4] = "./helpers/target/hdp_pie.zip";
        bytes memory abiEncoded = vm.ffi(inputs);
        return abi.decode(abiEncoded, (bytes32));
    }

    function _fetchCairoInput()
        internal
        returns (
            uint256 usedMmrId,
            uint256 usedMmrSize,
            bytes32 usedMmrRoot,
            bytes32 resultsMerkleRoot,
            bytes32 tasksMerkleRoot,
            bytes32[][] memory resultsInclusionProofs,
            bytes32[][] memory tasksInclusionProofs,
            bytes32[] memory resultsCommitments,
            bytes32[] memory tasksCommitments
        )
    {
        string[] memory inputs = new string[](2);
        inputs[0] = "node";
        inputs[1] = "./helpers/fetch_cairo_input.js";
        bytes memory abiEncoded = vm.ffi(inputs);
        (
            usedMmrId,
            usedMmrSize,
            usedMmrRoot,
            resultsMerkleRoot,
            tasksMerkleRoot,
            resultsInclusionProofs,
            tasksInclusionProofs,
            resultsCommitments,
            tasksCommitments
        ) = abi.decode(
            abiEncoded,
            (
                uint256,
                uint256,
                bytes32,
                bytes32,
                bytes32,
                bytes32[][],
                bytes32[][],
                bytes32[],
                bytes32[]
            )
        );
    }
}

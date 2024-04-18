// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test} from "forge-std/Test.sol";
import {HdpExecutionStore} from "../src/HdpExecutionStore.sol";
import {
    TransactionsInBlockDatalake,
    TransactionsInBlockDatalakeCodecs
} from "../src/datatypes/TransactionsInBlockDatalakeCodecs.sol";
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

    function createAggregator(uint256 id, ISharpFactsAggregator aggregator) external {
        aggregatorsById[id] = aggregator;
    }
}

contract MockSharpFactsAggregator is ISharpFactsAggregator {
    function aggregatorState() external pure returns (AggregatorState memory) {
        bytes32 root = 0x01b9d8032858854600ac6fb695a9367db1d48bf88cdf397549f18cd7a0e9320b;
        return AggregatorState({
            poseidonMmrRoot: root,
            keccakMmrRoot: bytes32(0),
            mmrSize: 1340626,
            continuableParentHash: bytes32(0)
        });
    }
}

contract TransactionsHdpExecutionStoreTest is Test {
    using TransactionsInBlockDatalakeCodecs for TransactionsInBlockDatalake;
    using ComputationalTaskCodecs for ComputationalTask;

    address public proverAddress = address(12);

    HdpExecutionStore private hdp;

    IFactsRegistry private factsRegistry;
    IAggregatorsFactory private aggregatorsFactory;

    ISharpFactsAggregator private sharpFactsAggregator;

    function setUp() public {
        // Registery for facts that has been processed through SHARP
        factsRegistry = new MockFactsRegistry();
        // Factory for creating SHARP facts aggregators
        aggregatorsFactory = new MockAggregatorsFactory();
        // Mock SHARP facts aggregator
        sharpFactsAggregator = new MockSharpFactsAggregator();
        hdp = new HdpExecutionStore(factsRegistry, aggregatorsFactory);

        // Step 0. Create mock SHARP facts aggregator mmr id 19
        aggregatorsFactory.createAggregator(19, sharpFactsAggregator);

        assertTrue(hdp.hasRole(keccak256("OPERATOR_ROLE"), address(this)));

        hdp.grantRole(keccak256("OPERATOR_ROLE"), proverAddress);
    }

    function testTransactionsInBlockDatalake() public {
        // hdp encode -a "sum" -t 5608949 "tx.nonce" 20
        // Note: Step 1. HDP Server receives a request
        // [1 Request = N Tasks] Request execution of task with block sampled datalake
        TransactionsInBlockDatalake memory datalake = TransactionsInBlockDatalake({
            targetBlock: 5608949,
            increment: 20,
            sampledProperty: TransactionsInBlockDatalakeCodecs.encodeSampledPropertyForTxProp(uint8(0))
        });

        ComputationalTask memory computationalTask =
            ComputationalTask({aggregateFnId: AggregateFn.SUM, operatorId: Operator.NONE, valueToCompare: uint256(0)});

        // datalakes: [
        //     Transactions(
        //         TransactionsInBlockDatalake {
        //             target_block: 5608949,
        //             sampled_property: Transactions(
        //                 Nonce,
        //             ),
        //             increment: 20,
        //         },
        //     ),
        // ]
        // 2024-04-18T05:53:46.551343Z  INFO hdp: tasks: [
        //     ComputationalTask {
        //         aggregate_fn_id: SUM,
        //         aggregate_fn_ctx: None,
        //     },
        // ]

        // =================================

        // Note: Step 2. HDP Server call [`requestExecutionOfTaskWithTransactionsInBlockDatalake`] before processing
        hdp.requestExecutionOfTaskWithTransactionsInBlockDatalake(datalake, computationalTask);

        // =================================

        // Note: This step is mocking requestExecutionOfTaskWithBlockSampledDatalake
        // create identifier to check request done correctly
        bytes32 datalakeCommitment = datalake.commit();
        bytes32 taskCommitment = computationalTask.commit(datalakeCommitment);

        assertEq(taskCommitment, bytes32(0x5a0573155e71e3eef728981b54a22d25fb9e38d32d487c116710ee56c1bcba35));

        // Check the task state is PENDING
        HdpExecutionStore.TaskStatus task1Status = hdp.getTaskStatus(taskCommitment);
        assertEq(uint256(task1Status), uint256(HdpExecutionStore.TaskStatus.SCHEDULED));

        // =================================

        // Note: Step 3. HDP Server process the request sending the tasks to the Rust HDP
        // This step is mocking cli call to Rust HDP

        // Request to cli

        // =================================

        // Encode datalakes
        bytes[] memory encodedDatalakes = new bytes[](1);
        encodedDatalakes[0] = datalake.encode();

        // Encode tasks
        bytes[] memory computationalTasksSerialized = new bytes[](1);
        computationalTasksSerialized[0] = computationalTask.encode();

        // =================================

        // Response from cli

        // Evaluation Result Key from cli
        bytes32[] memory taskCommitments = new bytes32[](1);
        taskCommitments[0] = taskCommitment;

        // Evaluation Result value from cli
        bytes32[] memory computationalTasksResult = new bytes32[](1);
        computationalTasksResult[0] = bytes32(uint256(40039));

        bytes32 taskResultCommitment1 = keccak256(abi.encode(taskCommitment, computationalTasksResult[0]));

        assertEq(taskResultCommitment1, bytes32(0x41770430274893b04a1dd63d61505c8538b25e33dffbb00014d17d59e98c5a06));

        // Tasks and Results Merkle Tree Information
        // proof of the tasks merkle tree
        bytes32[][] memory batchInclusionMerkleProofOfTasks = new bytes32[][](1);
        bytes32[] memory inclusionMerkleProofOfTask1 = new bytes32[](0);
        batchInclusionMerkleProofOfTasks[0] = inclusionMerkleProofOfTask1;

        // proof of the result
        bytes32[][] memory batchInclusionMerkleProofOfResults = new bytes32[][](1);
        bytes32[] memory inclusionMerkleProofOfResult1 = new bytes32[](0);
        batchInclusionMerkleProofOfResults[0] = inclusionMerkleProofOfResult1;

        uint256 taskMerkleRoot = uint256(bytes32(0x60870c80ce4e1d0c35e34f08b1648e8a4fdc7818eea7caedbd316c63a3863562));
        (uint256 taskRootLow, uint256 taskRootHigh) = Uint256Splitter.split128(taskMerkleRoot);
        uint128 scheduledTasksBatchMerkleRootLow = 0x4fdc7818eea7caedbd316c63a3863562;
        uint128 scheduledTasksBatchMerkleRootHigh = 0x60870c80ce4e1d0c35e34f08b1648e8a;
        assertEq(scheduledTasksBatchMerkleRootLow, taskRootLow);
        assertEq(scheduledTasksBatchMerkleRootHigh, taskRootHigh);

        uint256 resultMerkleRoot = uint256(bytes32(0xc23531a6b69aea98bc6e491fc9815a8bd8b416461f3a180784bfff195b4316e6));
        (uint256 resultRootLow, uint256 resultRootHigh) = Uint256Splitter.split128(resultMerkleRoot);
        uint128 batchResultsMerkleRootLow = 0xd8b416461f3a180784bfff195b4316e6;
        uint128 batchResultsMerkleRootHigh = 0xc23531a6b69aea98bc6e491fc9815a8b;
        assertEq(batchResultsMerkleRootLow, resultRootLow);
        assertEq(batchResultsMerkleRootHigh, resultRootHigh);

        // MMR metadata
        uint256 usedMmrId = 19;
        uint256 usedMmrSize = 1340626;

        // =================================

        // Cache MMR root
        hdp.cacheMmrRoot(usedMmrId);

        // Mocking Cairo Program, insert the fact into the registry
        bytes32 factHash = getFactHash(
            usedMmrId,
            usedMmrSize,
            batchResultsMerkleRootLow,
            batchResultsMerkleRootHigh,
            scheduledTasksBatchMerkleRootLow,
            scheduledTasksBatchMerkleRootHigh
        );
        assertEq(factHash, bytes32(0x075c14570f2960d50269578677f0a5fb4d13ae5a04d47d231ee529a0e7fc77df));
        factsRegistry.markValid(factHash);
        bool isValid = factsRegistry.isValid(factHash);
        assertEq(isValid, true);

        // =================================

        // Check if the request is valid in the SHARP Facts Registry
        // If valid, Store the task result
        vm.prank(proverAddress);
        hdp.authenticateTaskExecution(
            usedMmrId,
            usedMmrSize,
            batchResultsMerkleRootLow,
            batchResultsMerkleRootHigh,
            scheduledTasksBatchMerkleRootLow,
            scheduledTasksBatchMerkleRootHigh,
            batchInclusionMerkleProofOfTasks,
            batchInclusionMerkleProofOfResults,
            computationalTasksResult,
            taskCommitments
        );

        // Check if the task state is FINALIZED
        HdpExecutionStore.TaskStatus task1StatusAfter = hdp.getTaskStatus(taskCommitment);
        assertEq(uint256(task1StatusAfter), uint256(HdpExecutionStore.TaskStatus.FINALIZED));

        // Check if the task result is stored
        bytes32 task1Result = hdp.getFinalizedTaskResult(taskCommitment);
        assertEq(task1Result, computationalTasksResult[0]);
    }

    function getFactHash(
        uint256 usedMmrId,
        uint256 usedMmrSize,
        uint128 batchResultsMerkleRootLow,
        uint128 batchResultsMerkleRootHigh,
        uint128 scheduledTasksBatchMerkleRootLow,
        uint128 scheduledTasksBatchMerkleRootHigh
    ) internal view returns (bytes32) {
        // Load MMRs root
        bytes32 usedMmrRoot = hdp.loadMmrRoot(usedMmrId, usedMmrSize);
        // Initialize an array of uint256 to store the program output
        uint256[] memory programOutput = new uint256[](6);

        // Assign values to the program output array
        programOutput[0] = uint256(usedMmrRoot);
        programOutput[1] = uint256(usedMmrSize);
        programOutput[2] = uint256(batchResultsMerkleRootLow);
        programOutput[3] = uint256(batchResultsMerkleRootHigh);
        programOutput[4] = uint256(scheduledTasksBatchMerkleRootLow);
        programOutput[5] = uint256(scheduledTasksBatchMerkleRootHigh);

        // Compute program output hash
        bytes32 programOutputHash = keccak256(abi.encodePacked(programOutput));

        // Compute GPS fact hash
        bytes32 programHash = 0x05b1dad6ba5140fedd92861b0b8e0cbcd64eefb2fd59dcd60aa60cc1ba7c0eab;
        bytes32 gpsFactHash = keccak256(abi.encode(programHash, programOutputHash));

        return gpsFactHash;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

import {IFactsRegistry} from "./interfaces/IFactsRegistry.sol";
import {ISharpFactsAggregator} from "./interfaces/ISharpFactsAggregator.sol";
import {IAggregatorsFactory} from "./interfaces/IAggregatorsFactory.sol";

import {BlockSampledDatalake, BlockSampledDatalakeCodecs} from "./datatypes/BlockSampledDatalakeCodecs.sol";
import {
    TransactionsInBlockDatalake,
    TransactionsInBlockDatalakeCodecs
} from "./datatypes/TransactionsInBlockDatalakeCodecs.sol";
import {IterativeDynamicLayoutDatalake} from "./datatypes/IterativeDynamicLayoutDatalakeCodecs.sol";
import {IterativeDynamicLayoutDatalakeCodecs} from "./datatypes/IterativeDynamicLayoutDatalakeCodecs.sol";
import {ComputationalTask, ComputationalTaskCodecs} from "./datatypes/ComputationalTaskCodecs.sol";

/// Caller is not authorized to perform the action
error Unauthorized();
/// Task is already registered
error DoubleRegistration();
/// Fact doesn't exist in the registry
error InvalidFact();
/// Element is not in the batch
error NotInBatch();
/// Task is not finalized
error NotFinalized();

/// @title HdpExecutionStore
/// @author Herodotus Dev
/// @notice A contract to store the execution results of HDP tasks
contract HdpExecutionStore is AccessControl {
    using MerkleProof for bytes32[];
    using BlockSampledDatalakeCodecs for BlockSampledDatalake;
    using TransactionsInBlockDatalakeCodecs for TransactionsInBlockDatalake;
    using IterativeDynamicLayoutDatalakeCodecs for IterativeDynamicLayoutDatalake;
    using ComputationalTaskCodecs for ComputationalTask;

    /// @notice The status of a task
    enum TaskStatus {
        NONE,
        SCHEDULED,
        FINALIZED
    }

    /// @notice The struct representing a task result
    struct TaskResult {
        TaskStatus status;
        bytes32 result;
    }

    /// @notice emitted when a new MMR root is cached
    event MmrRootCached(uint256 mmrId, uint256 mmrSize, bytes32 mmrRoot);

    /// @notice emitted when a new task with block sampled datalake is scheduled
    event TaskWithBlockSampledDatalakeScheduled(BlockSampledDatalake datalake, ComputationalTask task);

    /// @notice emitted when a new task with transactions in block datalake is scheduled
    event TaskWithTransactionsInBlockDatalakeScheduled(TransactionsInBlockDatalake datalake, ComputationalTask task);

    /// @notice constant representing role of operator
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @notice constant representing the pedersen hash of the Cairo HDP program
    bytes32 public immutable PROGRAM_HASH;

    /// @notice interface to the facts registry of SHARP
    IFactsRegistry public immutable SHARP_FACTS_REGISTRY;

    /// @notice immutable representing the chain id
    uint256 public immutable CHAIN_ID;

    /// @notice interface to the aggregators factory
    IAggregatorsFactory public immutable AGGREGATORS_FACTORY;

    /// @notice mapping of task result hash => task
    mapping(bytes32 => TaskResult) public cachedTasksResult;

    /// @notice mapping of chain id => mmr id => mmr size => mmr root
    mapping(uint256 => mapping(uint256 => mapping(uint256 => bytes32))) public cachedMMRsRoots;

    constructor(IFactsRegistry factsRegistry, IAggregatorsFactory aggregatorsFactory, bytes32 programHash) {
        SHARP_FACTS_REGISTRY = factsRegistry;
        AGGREGATORS_FACTORY = aggregatorsFactory;
        PROGRAM_HASH = programHash;
        CHAIN_ID = block.chainid;

        _setRoleAdmin(OPERATOR_ROLE, OPERATOR_ROLE);
        _grantRole(OPERATOR_ROLE, _msgSender());
    }

    /// @notice Reverts if the caller is not an operator
    modifier onlyOperator() {
        if (!hasRole(OPERATOR_ROLE, _msgSender())) revert Unauthorized();
        _;
    }

    /// @notice Caches the MMR root for a given MMR id
    /// @notice Get MMR size and root from the aggregator and cache it
    function cacheMmrRoot(uint256 mmrId) public {
        ISharpFactsAggregator aggregator = AGGREGATORS_FACTORY.aggregatorsById(mmrId);
        ISharpFactsAggregator.AggregatorState memory aggregatorState = aggregator.aggregatorState();
        cachedMMRsRoots[CHAIN_ID][mmrId][aggregatorState.mmrSize] = aggregatorState.poseidonMmrRoot;

        emit MmrRootCached(mmrId, aggregatorState.mmrSize, aggregatorState.poseidonMmrRoot);
    }

    /// @notice Requests the execution of a task with a block sampled datalake
    /// @param blockSampledDatalake The block sampled datalake
    /// @param computationalTask The computational task
    function requestExecutionOfTaskWithBlockSampledDatalake(
        BlockSampledDatalake calldata blockSampledDatalake,
        ComputationalTask calldata computationalTask
    ) external {
        bytes32 datalakeCommitment = blockSampledDatalake.commit();
        bytes32 taskCommitment = computationalTask.commit(datalakeCommitment);

        // Ensure task is not already scheduled
        if (cachedTasksResult[taskCommitment].status != TaskStatus.NONE) {
            revert DoubleRegistration();
        }

        // Store the task result
        cachedTasksResult[taskCommitment] = TaskResult({status: TaskStatus.SCHEDULED, result: ""});

        emit TaskWithBlockSampledDatalakeScheduled(blockSampledDatalake, computationalTask);
    }

    /// @notice Requests the execution of a task with a transactions in block datalake
    /// @param transactionsInBlockDatalake The transactions in block datalake
    /// @param computationalTask The computational task
    function requestExecutionOfTaskWithTransactionsInBlockDatalake(
        TransactionsInBlockDatalake calldata transactionsInBlockDatalake,
        ComputationalTask calldata computationalTask
    ) external {
        bytes32 datalakeCommitment = transactionsInBlockDatalake.commit();
        bytes32 taskCommitment = computationalTask.commit(datalakeCommitment);

        // Ensure task is not already scheduled
        if (cachedTasksResult[taskCommitment].status != TaskStatus.NONE) {
            revert DoubleRegistration();
        }

        // Store the task result
        cachedTasksResult[taskCommitment] = TaskResult({status: TaskStatus.SCHEDULED, result: ""});

        emit TaskWithTransactionsInBlockDatalakeScheduled(transactionsInBlockDatalake, computationalTask);
    }

    /// @notice Authenticates the execution of a task is finalized
    ///     by verifying the FactRegistry and Merkle proofs
    /// @param mmrIds The id of the MMR used to compute task
    /// @param mmrSizes The size of the MMR used to compute task
    /// @param taskMerkleRootLow The low 128 bits of the tasks Merkle root
    /// @param taskMerkleRootHigh The high 128 bits of the tasks Merkle root
    /// @param resultMerkleRootLow The low 128 bits of the results Merkle root
    /// @param resultMerkleRootHigh The high 128 bits of the results Merkle root
    /// @param tasksInclusionProofs The Merkle proof of the tasks
    /// @param resultsInclusionProofs The Merkle proof of the results
    /// @param taskCommitments The commitment of the tasks
    /// @param taskResults The result of the computational tasks
    function authenticateTaskExecution(
        uint256[] calldata mmrIds,
        uint256[] calldata mmrSizes,
        uint256 taskMerkleRootLow,
        uint256 taskMerkleRootHigh,
        uint256 resultMerkleRootLow,
        uint256 resultMerkleRootHigh,
        bytes32[][] memory tasksInclusionProofs,
        bytes32[][] memory resultsInclusionProofs,
        bytes32[] calldata taskCommitments,
        bytes32[] calldata taskResults
    ) external onlyOperator {
        assert(mmrIds.length == mmrSizes.length);

        // Initialize an array of uint256 to store the program output
        uint256[] memory programOutput = new uint256[](4 + mmrIds.length * 4);

        // Assign values to the program output array
        programOutput[0] = resultMerkleRootLow;
        programOutput[1] = resultMerkleRootHigh;
        programOutput[2] = taskMerkleRootLow;
        programOutput[3] = taskMerkleRootHigh;

        for (uint8 i = 0; i < mmrIds.length; i++) {
            bytes32 usedMmrRoot = loadMmrRoot(mmrIds[i], mmrSizes[i]);
            programOutput[4 + i * 4] = mmrIds[i];
            programOutput[4 + i * 4 + 1] = mmrSizes[i];
            programOutput[4 + i * 4 + 2] = CHAIN_ID;
            programOutput[4 + i * 4 + 3] = uint256(usedMmrRoot);
        }

        // Compute program output hash
        bytes32 programOutputHash = keccak256(abi.encodePacked(programOutput));

        // Compute GPS fact hash
        bytes32 gpsFactHash = keccak256(abi.encode(PROGRAM_HASH, programOutputHash));

        // Ensure GPS fact is registered
        if (!SHARP_FACTS_REGISTRY.isValid(gpsFactHash)) {
            revert InvalidFact();
        }

        // Loop through all the tasks in the batch
        for (uint256 i = 0; i < taskResults.length; i++) {
            bytes32 computationalTaskResult = taskResults[i];
            bytes32[] memory taskInclusionProof = tasksInclusionProofs[i];
            bytes32[] memory resultInclusionProof = resultsInclusionProofs[i];

            // Convert the low and high 128 bits to a single 256 bit value
            bytes32 resultMerkleRoot = bytes32((resultMerkleRootHigh << 128) | resultMerkleRootLow);
            bytes32 taskMerkleRoot = bytes32((taskMerkleRootHigh << 128) | taskMerkleRootLow);

            // Compute the Merkle leaf of the task
            bytes32 taskCommitment = taskCommitments[i];
            bytes32 taskMerkleLeaf = standardLeafHash(taskCommitment);
            // Ensure that the task is included in the batch, by verifying the Merkle proof
            bool isVerifiedTask = taskInclusionProof.verify(taskMerkleRoot, taskMerkleLeaf);

            if (!isVerifiedTask) {
                revert NotInBatch();
            }

            // Compute the Merkle leaf of the task result
            bytes32 taskResultCommitment = keccak256(abi.encode(taskCommitment, computationalTaskResult));
            bytes32 taskResultMerkleLeaf = standardLeafHash(taskResultCommitment);
            // Ensure that the task result is included in the batch, by verifying the Merkle proof
            bool isVerifiedResult = resultInclusionProof.verify(resultMerkleRoot, taskResultMerkleLeaf);

            if (!isVerifiedResult) {
                revert NotInBatch();
            }

            // Store the task result
            cachedTasksResult[taskCommitment] =
                TaskResult({status: TaskStatus.FINALIZED, result: computationalTaskResult});
        }
    }

    /// @notice Load MMR root from cache with given mmrId and mmrSize
    function loadMmrRoot(uint256 mmrId, uint256 mmrSize) public view returns (bytes32) {
        return cachedMMRsRoots[CHAIN_ID][mmrId][mmrSize];
    }

    /// @notice Returns the result of a finalized task
    function getFinalizedTaskResult(bytes32 taskCommitment) external view returns (bytes32) {
        // Ensure task is finalized
        if (cachedTasksResult[taskCommitment].status != TaskStatus.FINALIZED) {
            revert NotFinalized();
        }
        return cachedTasksResult[taskCommitment].result;
    }

    /// @notice Returns the status of a task
    function getTaskStatus(bytes32 taskCommitment) external view returns (TaskStatus) {
        return cachedTasksResult[taskCommitment].status;
    }

    /// @notice Returns the leaf of standard merkle tree
    function standardLeafHash(bytes32 value) public pure returns (bytes32) {
        bytes32 firstHash = keccak256(abi.encode(value));
        bytes32 leaf = keccak256(abi.encode(firstHash));
        return leaf;
    }
}

![](.github/readme.png)

# HDP Solidity

![CI](https://github.com/HerodotusDev/hdp-solidity/actions/workflows/test.yml/badge.svg)

> **Warning**: This codebase is experimental and not audited. Use at your own risk.

## Introduction

The HDP Solidity contracts interface with the Herodotus Data Processor (HDP) to authenticate and store processed results securely on-chain. These contracts facilitate complex data processing tasks and result in validation using cryptographic proofs. For more, visit our [documentation](https://docs.herodotus.dev/herodotus-docs/developers/herodotus-data-processor-hdp).

## Contract Overview

`HdpExecutionStore` is the main contract in this project. It manages the execution and verification of computational tasks on various datalakes like block-sampled datalake. The contract integrates multiple functionalities:

- **Task Scheduling and Result Caching**: Allows scheduling of tasks and caching of intermediate and final results.
- **Merkle Proof Verification**: Utilizes Merkle proofs to ensure the integrity of task results and batch inclusions.
- **Integration with External Fact Registries and Aggregators**: Verifies task computations against a set of pre-registered facts using the SHARP Facts Registry and coordinates with data aggregators.

### Key Functions

- `requestExecutionOfTaskWithBlockSampledDatalake()`: Schedules computational tasks using block-sampled data.
- `authenticateTaskExecution()`: Verifies and finalizes the execution of computational tasks by validating Merkle proofs and registered facts.
- `getFinalizedTaskResult()`: Retrieves results of finalized tasks.

## External Contracts

- **FactsRegistry**: Manages facts for task verification. [More info](https://github.com/starkware-libs/starkex-contracts/blob/master/scalable-dex/contracts/src/components/FactRegistry.sol)
- **SharpFactsAggregator**: Aggregates jobs [More info](https://github.com/HerodotusDev/offchain-evm-headers-processor/blob/main/solidity-verifier/src/SharpFactsAggregator.sol)
- **AggregatorsFactory**: Factory pattern to create data aggregators. [More info](https://github.com/HerodotusDev/offchain-evm-headers-processor/blob/main/solidity-verifier/src/AggregatorsFactory.sol)

## Data Structures

### Data Lakes

- **BlockSampledDatalake**:
  - Structure used for defining data samples over a range of blocks.
  - Encoded through `BlockSampledDatalakeCodecs` which manages the serialization and commitment of these data structures.
  - `commit()` function creates a hash of the encoded datalake, used for verifying integrity and registering tasks.

### Computational Tasks

- **ComputationalTask**:
  - Defines tasks that perform aggregate functions on the data retrieved from datalakes.
  - Encoded and committed using `ComputationalTaskCodecs`, ensuring that tasks are securely and efficiently processed.
  - Supported functions include average, sum, min, max, count, and Merkle proof aggregation, with various operators for conditional processing.

## Codecs

### Key Codec Functions

- `encode()`: Serializes data structures for transmission or storage.
- `commit()`: Generates cryptographic commitments of data, essential for task verification and integrity checks.
- `decode()`: Converts serialized data back into structured formats.

## Getting Started

Pre-requisites:

- Solidity (with solc >= 0.8.4)
- Foundry

## Deployment

Make sure to have a `.env` file configured with the variables defined in `.env.example`, then run:

```sh
source .env; forge script script/HdpExecutionStore.s.sol:HdpExecutionStoreDeployer --rpc-url $DEPLOY_RPC_URL --broadcast --verify -vvvv --via-ir
```

## Quick Start

For one time local Cairo environment:

```sh
make cairo-install

```

For one time local `hdp` cli executable:

```sh
cargo install --git https://github.com/HerodotusDev/hdp --locked --force
```

For the setup require to run test:

```sh
make setup
```

Now can run test from the setup above:

```sh
# Install submodules
forge install

# Build contracts
forge build

# Test
forge test
```

## License

`hdp-solidity` is licensed under the [GNU General Public License v3.0](./LICENSE).

---

Herodotus Dev Ltd - 2024

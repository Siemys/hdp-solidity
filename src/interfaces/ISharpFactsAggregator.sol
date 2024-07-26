// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

/// @notice Interface for the SharpFactsAggregator.
interface ISharpFactsAggregator {
    struct AggregatorState {
        bytes32 poseidonMmrRoot;
        bytes32 keccakMmrRoot;
        uint256 mmrSize;
        bytes32 continuableParentHash;
    }

    function aggregatorState() external view returns (AggregatorState memory);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import {ISharpFactsAggregator} from "./ISharpFactsAggregator.sol";

/// @notice Aggregators factory interface.
interface IAggregatorsFactory {
    function createAggregator(uint256 id, ISharpFactsAggregator aggregator) external;

    function aggregatorsById(uint256 id) external view returns (ISharpFactsAggregator);
}

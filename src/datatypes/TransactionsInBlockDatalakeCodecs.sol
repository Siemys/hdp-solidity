// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {DatalakeCode} from "./Datalake.sol";

/// @dev A TransactionsInBlockDatalake.
/// @param targetBlock The block to sample trnasactions from.
/// @param increment The transactions increment.
/// @param sampledProperty The detail property to sample.
struct TransactionsInBlockDatalake {
    uint256 targetBlock;
    uint256 increment;
    bytes sampledProperty;
}

/// @notice Codecs for TransactionsInBlockDatalake.
/// @dev Represent a datalake that samples a property at a fixed block interval.
library TransactionsInBlockDatalakeCodecs {
    /// @dev Encodes a TransactionsInBlockDatalake.
    /// @param datalake The TransactionsInBlockDatalake to encode.
    function encode(TransactionsInBlockDatalake memory datalake) internal pure returns (bytes memory) {
        return abi.encode(
            DatalakeCode.TransactionsInBlock, datalake.targetBlock, datalake.increment, datalake.sampledProperty
        );
    }

    /// @dev Get the commitment of a TransactionsInBlockDatalake.
    /// @param datalake The TransactionsInBlockDatalake to commit.
    function commit(TransactionsInBlockDatalake memory datalake) internal pure returns (bytes32) {
        return keccak256(encode(datalake));
    }

    /// @dev Encodes a sampled property for a transaction property.
    /// @param txPropId The field from rlp decoded block tx.
    function encodeSampledPropertyForTxProp(uint8 txPropId) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(1), txPropId);
    }

    /// @dev Encodes a sampled property for an transaction receipt property.
    /// @param txReceiptPropId The field from rlp decoded block transaction receipt.
    function encodeSampledPropertyFortxReceipt(uint8 txReceiptPropId) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(2), txReceiptPropId);
    }

    /// @dev Decodes a TransactionsInBlockDatalake.
    /// @param data The encoded TransactionsInBlockDatalake.
    function decode(bytes memory data) internal pure returns (TransactionsInBlockDatalake memory) {
        (, uint256 targetBlock, uint256 increment, bytes memory sampledProperty) =
            abi.decode(data, (DatalakeCode, uint256, uint256, bytes));
        return TransactionsInBlockDatalake({
            targetBlock: targetBlock,
            increment: increment,
            sampledProperty: sampledProperty
        });
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ICommon} from "./ICommon.sol";

interface ICorkSwapAggregator is ICommon {
    function swap(AggregatorParams calldata params, address caller) external returns (uint256 amountOut);
}

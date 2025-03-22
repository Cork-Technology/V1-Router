// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ICommon} from "./ICommon.sol";

interface ICorkSwapAggregator is ICommon {
    /**
     * @notice Executes a token swap via KyberSwap
     * @dev Pulls tokens from caller, approves and executes swap via KyberSwap, then returns output tokens.
     * @param params The aggregator parameters including token addresses, amounts, and external router data
     * @param caller The address that initiated the swap (not used in current implementation)
     * @return amountOut The amount of output tokens received from the swap
     * @custom:reverts If token transfers fail, approvals fail, or if the underlying swap fails
     * @custom:reverts If the token addresses are invalid or if minimum output amount is not met
     */
    function swap(AggregatorParams calldata params, address caller) external returns (uint256 amountOut);
}

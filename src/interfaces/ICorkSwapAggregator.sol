// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {IDsFlashSwapCore} from "Depeg-swap/contracts/interfaces/IDsFlashSwapRouter.sol";

interface ICorkSwapAggregator {
    /// @notice Thrown when the address is zero
    error ZeroAddress();

    // TODO : make checks for checking token in and token out is the same when aggregator is disabled
    struct AggregatorParams {
        // the input token address, if enableAggregator is false
        // you should set this as the target RA/PA if you're doing a "zap" out swap
        // e.g swapping CT -> RA -> Other Token
        // else set this as the token you want to swap if doing "zap" in swap
        // e.g swapping Other Token -> RA -> CT
        address tokenIn;
        // the output token address,
        // user must set the same token address as token in if aggregator is disabled
        // set this as the token you want to swap if doing "zap" in swap
        // e.g swapping Other Token -> RA -> CT (set this to RA
        // else set this as the target RA/PA if you're doing a "zap" out swap
        // e.g swapping CT -> RA -> Other Token
        address tokenOut;
        // the input token amount
        // set this to 0 when doing exact out swaps
        uint256 amountIn;
        // the output token target amount
        // set this to 0 when doing exact in swaps
        uint256 amountOut;
        // the output token slippage protection
        // the user must set the same value as amountIn if the aggregator is disabled
        // set this to 0 when doing exact out swaps on the aggregator
        uint256 amountOutMin;
        // the input token slippage protection when doing exact in swaps
        // the user must set the same value as amountIn if the aggregator is disabled
        // set this to 0 when doing exact in swaps on the aggregator
        uint256 amountMaxIn;
        // external swap aggregator, won't be used if enableAggregator is set to false
        address extRouter;
        // external swap aggregator calldata, won't be used if enableAggregator is set to false
        bytes extRouterData;
        // if set to true will use external aggregator to swap token in to token out, and do the protocol interaction with token out
        bool enableAggregator;
    }

    // pass this as bytes data when redeeming LV via the router
    struct LvRedeemParams {
        address receiver;
        Id id;
        // frontend should do the same logic as the contract and then
        // do a sell DS preview to get this value
        uint256 dsMinOut;
        // aggregator swap data for pa token -> RA
        // the amount in should include the amount of idle PA and the PA we got from redeeming CT(if the CT is expired)
        ICorkSwapAggregator.AggregatorParams paSwapAggregatorData;
    }

    struct SwapRaForDsParams {
        Id id;
        uint256 dsId;
        uint256 amountOutMin;
        IDsFlashSwapCore.BuyAprroxParams approxParams;
        IDsFlashSwapCore.OffchainGuess offchainGuess;
        ICorkSwapAggregator.AggregatorParams inputTokenAggregatorParams;
    }

    struct SwapDsForRaParams {
        Id id;
        uint256 dsId;
        uint256 amount;
        uint256 raAmountOutMin;
        ICorkSwapAggregator.AggregatorParams raAggregatorParams;
    }

    function swap(AggregatorParams calldata params, address caller) external returns (uint256 amountOut);
}

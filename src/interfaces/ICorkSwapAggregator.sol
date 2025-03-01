// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";

interface ICorkSwapAggregator {
    struct SwapParams {
        // the inout token address
        address tokenIn;
        // the output token address, won't be used if enable aggregator is set to false
        address tokenOut;
        // the input token amount
        uint256 amountIn;
        // the output token slippage protection, won't be used if enable aggregator is set to false
        uint256 amountOutMin;
        // external swap aggregator, won't be used if enableAggregator is set to false
        address extRouter;
        // external swap aggregator calldata, won't be used if enableAggregator is set to false
        bytes extRouterData;
        // if set to true will use external router to swap token in to token out, and do the protocol interaction with token out
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
        ICorkSwapAggregator.SwapParams paSwapAggregatorData;
    }

    function swap(SwapParams calldata params) external returns (uint256 amountOut);
}

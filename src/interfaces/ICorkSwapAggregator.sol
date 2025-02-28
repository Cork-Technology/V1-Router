// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";

interface ICorkSwapAggregator {
    struct SwapParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOutMin;
        address extRouter;
        bytes extRouterData;
    }

    // pass this as bytes data when redeeming LV via the router
    struct RouterParams {
        address receiver;
        Id id;
        // frontend should do the same logic as the contract and then
        // do a sell DS preview to get this value
        uint256 dsMinOut;
        // aggregator swap data for pa token -> RA
        // the amount in should include the amount of idle PA and the PA we got from redeeming CT(if the CT is expired)
        ICorkSwapAggregator.SwapParams paSwapAggregatorData;
        // if set to false then the cork router will not use external router to convert the PA -> RA
        // so user instead will get both RA + PA
        bool useExtRouter;
    }

    function swap(SwapParams calldata params) external returns (uint256 amountOut);
}

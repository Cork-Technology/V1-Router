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
        Id id;
        // frontend should do the same logic as the contract and then
        // do a sell DS preview to get this value
        uint256 dsMinOut;
        // aggregator swap data for pa token -> RA
        ICorkSwapAggregator.SwapParams paSwapAggregatorData;
    }

    function swap(SwapParams calldata params) external returns (uint256 amountOut);
}

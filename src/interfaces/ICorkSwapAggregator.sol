pragma solidity ^0.8.28;

interface ICorkSwapAggregator {
    struct SwapParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOutMin;
        address extRouter;
        bytes extRouterData;
    }

    function swap(SwapParams calldata params) external returns (uint256 amountOut);
}

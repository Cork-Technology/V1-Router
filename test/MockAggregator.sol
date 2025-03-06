pragma solidity ^0.8.26;

import {ICorkSwapAggregator} from "../src/interfaces/ICorkSwapAggregator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockAggregator is ICorkSwapAggregator {
    function swap(AggregatorParams calldata params, address caller) external returns (uint256 amountOut) {
        // "consume" the input token
        IERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn);

        // simply transfer the same amountOut as amountIn and return it
        IERC20(params.tokenOut).transfer(msg.sender, params.amountIn);
        return params.amountIn;
    }
}

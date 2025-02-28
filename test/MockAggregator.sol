pragma solidity ^0.8.26;

import {ICorkSwapAggregator} from "../src/interfaces/ICorkSwapAggregator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockAggregator is ICorkSwapAggregator {
    function swap(SwapParams calldata params) external returns (uint256 amountOut) {
        IERC20(params.tokenOut).transfer(msg.sender, params.amountIn);
        // simply transfer the same amountOut as amountIn
        return params.amountIn;
    }
}

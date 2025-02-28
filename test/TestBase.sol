pragma solidity ^0.8.26;

import {Helper} from "Depeg-swap/test/forge/Helper.sol";
import {MockAggregator} from "./MockAggregator.sol";
import {DummyWETH} from "Depeg-swap/contracts/dummy/DummyWETH.sol";
import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {CorkRouterV1} from "./../src/CorkRouterV1.sol";
import {ICorkSwapAggregator} from "../src/interfaces/ICorkSwapAggregator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestBase is Helper {
    CorkRouterV1 public router;
    MockAggregator public mockAggregator;
    address caller;

    function initTests() internal {
        vm.startPrank(DEFAULT_ADDRESS);
        deployModuleCore();
        vm.stopPrank();

        mockAggregator = new MockAggregator();
        router = new CorkRouterV1(address(moduleCore), address(flashSwapRouter), address(hook));
    }

    function _recordCallers() internal {
        (, caller,) = vm.readCallers();
    }

    function _backToCaller() internal {
        vm.startPrank(caller);
    }

    modifier callerCheckPoint() {
        _recordCallers();
        vm.stopPrank();
        _;
        _backToCaller();
    }

    function bootstrapAggregatorLiquidity(DummyWETH token) internal callerCheckPoint {
        address aggregator = address(mockAggregator);

        vm.deal(aggregator, type(uint128).max);

        vm.startPrank(aggregator);
        token.deposit{value: type(uint128).max}();
        vm.stopPrank();
    }

    function bootstrapSelfLiquidity(DummyWETH token) internal callerCheckPoint {
        vm.deal(caller, type(uint128).max);
        vm.prank(caller);

        token.deposit{value: type(uint128).max}();
    }

    function allowFullAllowance(address token, address to) internal {
        IERC20(token).approve(to, type(uint128).max);
    }

    function defaultSwapParams(address tokenIn, address tokenOut, uint256 amountIn)
        internal
        view
        returns (ICorkSwapAggregator.SwapParams memory params)
    {
        params.tokenIn = tokenIn;
        params.tokenOut = tokenOut;
        params.amountIn = amountIn;
        params.extRouter = address(mockAggregator);
        params.extRouterData = "";
    }
}

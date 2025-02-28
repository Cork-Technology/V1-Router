pragma solidity ^0.8.26;

<<<<<<< Updated upstream
import {TestHelper} from "Depeg-swap/test/forge/Helper.sol";

contract TestBase is TestHelper {
    function a() internal {}
=======
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

    function initTests() internal {
        mockAggregator = new MockAggregator();
        router = new CorkRouterV1(address(moduleCore), address(flashSwapRouter), address(hook));

        vm.startPrank(DEFAULT_ADDRESS);
        deployModuleCore();
        vm.stopPrank();
    }

    function bootstrapAggregatorLiquidity(DummyWETH token) internal {
        address aggregator = address(mockAggregator);
        vm.deal(aggregator, type(uint128).max);

        vm.startPrank(aggregator);
        token.deposit{value: type(uint128).max}();
        vm.stopPrank();
    }

    function bootstrapSelfLiquidity(DummyWETH token) internal {
        (, address caller,) = vm.readCallers();

        vm.deal(caller, type(uint128).max);
        vm.prank(caller);
        token.deposit{value: type(uint128).max}();
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

    function allowFullAccess(address token, address tp) internal {
        (, address caller,) = vm.readCallers();
        vm.startPrank(caller);
        IERC20(token).approve(tp, type(uint128).max);
        vm.stopPrank();
    }
>>>>>>> Stashed changes
}

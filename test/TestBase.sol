pragma solidity ^0.8.26;

import {Helper} from "Depeg-swap/test/forge/Helper.sol";
import {MockAggregator} from "./MockAggregator.sol";
import {DummyWETH} from "Depeg-swap/test/utils/dummy/DummyWETH.sol";
import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {CorkRouterV1} from "./../src/CorkRouterV1.sol";
import {ICorkSwapAggregator} from "../src/interfaces/ICorkSwapAggregator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TestBase is Helper {
    CorkRouterV1 public router;
    MockAggregator public mockAggregator;
    address caller;
    uint256 stateId;

    function initTests() internal {
        vm.startPrank(DEFAULT_ADDRESS);
        deployModuleCore();
        vm.stopPrank();

        mockAggregator = new MockAggregator();
        router = new CorkRouterV1();

        ERC1967Proxy proxy = new ERC1967Proxy(address(router), "");
        router = CorkRouterV1(address(proxy));

        router.initialize(address(moduleCore), address(flashSwapRouter), address(hook), DEFAULT_ADDRESS);
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

    function balance(address token, address who) internal returns (uint256) {
        return IERC20(token).balanceOf(who);
    }

    function defaultAggregatorParams(address tokenIn, address tokenOut, uint256 amountIn)
        internal
        view
        returns (ICorkSwapAggregator.AggregatorParams memory params)
    {
        params.tokenIn = tokenIn;
        params.tokenOut = tokenOut;
        params.amountIn = amountIn;
        params.extRouter = address(mockAggregator);
        params.extRouterData = "";
        params.enableAggregator = true;
    }

    function _verifyNoFunds(IERC20 token, address target) internal {
        uint256 tokenBalance = token.balanceOf(target);
        assertEq(tokenBalance, 0);
    }

    function _verifyNoFunds(address token, address target) internal {
        _verifyNoFunds(IERC20(token), target);
    }

    function snap() internal {
        stateId = vm.snapshotState();
    }

    function restore() internal {
        vm.revertToState(stateId);
    }
}

pragma solidity ^0.8.26;

// solhint-disable

import {TestBase} from "./../TestBase.sol";
import {DummyWETH} from "Depeg-swap/test/utils/dummy/DummyWETH.sol";
import {ICommon} from "../../src/interfaces/ICommon.sol";
import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDsFlashSwapCore} from "Depeg-swap/contracts/interfaces/IDsFlashSwapRouter.sol";

contract SwapCt is TestBase {
    DummyWETH internal ra;
    DummyWETH internal pa;
    DummyWETH internal randomToken;

    address ct;
    address ds;

    function setUp() public {
        initTests();
        vm.startPrank(DEFAULT_ADDRESS);

        randomToken = new DummyWETH();

        (ra, pa,) = initializeAndIssueNewDs(10 days);

        bootstrapAggregatorLiquidity(ra);
        bootstrapAggregatorLiquidity(randomToken);

        bootstrapSelfLiquidity(ra);
        bootstrapSelfLiquidity(pa);
        bootstrapSelfLiquidity(randomToken);

        allowFullAllowance(address(randomToken), address(router));
        allowFullAllowance(address(ra), address(router));
        allowFullAllowance(address(pa), address(router));
        allowFullAllowance(address(ra), address(moduleCore));
        allowFullAllowance(address(pa), address(moduleCore));

        (ct, ds) = moduleCore.swapAsset(defaultCurrencyId, 1);

        allowFullAllowance(ct, address(router));
        allowFullAllowance(ds, address(router));

        // add liquidity
        moduleCore.depositLv(defaultCurrencyId, 10 ether, 0, 0);
        moduleCore.depositPsm(defaultCurrencyId, 10 ether);
    }

    function testFuzzSwapRaCtExactIn(bool enableAggregator) external {
        uint256 amountIn = 0.1 ether;

        address tokenIn = enableAggregator ? address(randomToken) : address(ra);
        address tokenOut = address(ra);

        ICommon.AggregatorParams memory AggregatorParams = defaultAggregatorParams(tokenIn, tokenOut, amountIn);

        uint256 tokenInBalanceBefore = balance(tokenIn, DEFAULT_ADDRESS);
        uint256 tokenOutBalanceBefore = balance(ct, DEFAULT_ADDRESS);

        // test slippage
        vm.expectRevert();
        router.swapRaForCtExactIn(AggregatorParams, defaultCurrencyId, 100000 ether);

        uint256 amountOut = router.swapRaForCtExactIn(AggregatorParams, defaultCurrencyId, 0);

        uint256 tokenInBalanceAfter = balance(tokenIn, DEFAULT_ADDRESS);
        uint256 tokenOutBalanceAfter = balance(ct, DEFAULT_ADDRESS);

        assertEq(tokenInBalanceBefore - tokenInBalanceAfter, amountIn);
        assertEq(tokenOutBalanceAfter - tokenOutBalanceBefore, amountOut);

        _verifyNoFunds(ct, address(router));
        _verifyNoFunds(address(ra), address(router));
        _verifyNoFunds(address(randomToken), address(router));
    }

    function testFuzzSwapRaCtExactOut(bool enableAggregator) external {
        // this what we approximately get for 0.1 RA
        uint256 amountOutExpected = 96e15;
        uint256 amountIn = 0.157 ether;

        address tokenIn = enableAggregator ? address(randomToken) : address(ra);
        address tokenOut = address(ra);

        uint256 tokenInBalanceBefore = balance(address(ra), DEFAULT_ADDRESS);
        uint256 tokenOutBalanceBefore = balance(ct, DEFAULT_ADDRESS);

        ICommon.AggregatorParams memory AggregatorParams = defaultAggregatorParams(tokenIn, tokenOut, amountIn);

        (uint256 used, uint256 remaining) =
            router.swapRaForCtExactOut(AggregatorParams, defaultCurrencyId, amountOutExpected);

        uint256 tokenInBalanceAfter = balance(address(ra), DEFAULT_ADDRESS);
        uint256 tokenOutBalanceAfter = balance(ct, DEFAULT_ADDRESS);

        if (enableAggregator) {
            assertEq(tokenInBalanceAfter - tokenInBalanceBefore, remaining);
        } else {
            assertEq(tokenInBalanceBefore - tokenInBalanceAfter, used);
        }

        assertEq(tokenOutBalanceAfter - tokenOutBalanceBefore, amountOutExpected);

        _verifyNoFunds(ct, address(router));
        _verifyNoFunds(address(ra), address(router));
        _verifyNoFunds(address(randomToken), address(router));
    }

    function testFuzzSwapCtRaExactIn(bool enableAggregator) external {
        uint256 amountIn = 0.1 ether;

        address tokenIn = address(ra);
        address tokenOut = enableAggregator ? address(randomToken) : address(ra);

        ICommon.AggregatorParams memory AggregatorParams = defaultAggregatorParams(tokenIn, tokenOut, amountIn);

        uint256 tokenInBalanceBefore = balance(ct, DEFAULT_ADDRESS);
        uint256 tokenOutBalanceBefore = balance(tokenOut, DEFAULT_ADDRESS);

        // test slippage
        vm.expectRevert();
        router.swapCtForRaExactIn(AggregatorParams, defaultCurrencyId, amountIn, 100000 ether);

        // use this without aggregator first to get the RA,
        // then we will revert the state so that we can test the aggregator with accurate RA
        snap();
        ICommon.AggregatorParams memory mockAggregatorParams = defaultAggregatorParams(tokenIn, tokenIn, 0);
        uint256 amountOut = router.swapCtForRaExactIn(AggregatorParams, defaultCurrencyId, amountIn, 0);
        restore();

        AggregatorParams.amountIn = amountOut;
        amountOut = router.swapCtForRaExactIn(AggregatorParams, defaultCurrencyId, amountIn, 0);

        uint256 tokenInBalanceAfter = balance(ct, DEFAULT_ADDRESS);
        uint256 tokenOutBalanceAfter = balance(tokenOut, DEFAULT_ADDRESS);

        assertEq(tokenInBalanceBefore - tokenInBalanceAfter, amountIn);
        assertEq(tokenOutBalanceAfter - tokenOutBalanceBefore, amountOut);

        _verifyNoFunds(ct, address(router));
        _verifyNoFunds(address(ra), address(router));
        _verifyNoFunds(address(randomToken), address(router));
    }

    function testFuzzSwapCtRaExactOut(bool enableAggregator) external {
        uint256 amountIn = 0.157 ether;
        uint256 amountOutExpected = 96e15;

        address tokenIn = address(ra);
        address tokenOut = enableAggregator ? address(randomToken) : address(ra);

        ICommon.AggregatorParams memory AggregatorParams = defaultAggregatorParams(tokenIn, tokenOut, amountOutExpected);

        uint256 tokenInBalanceBefore = balance(ct, DEFAULT_ADDRESS);
        uint256 tokenOutBalanceBefore = balance(tokenOut, DEFAULT_ADDRESS);

        (uint256 used, uint256 remaining, uint256 tokenOutAmountOut) =
            router.swapCtForRaExactOut(AggregatorParams, defaultCurrencyId, amountOutExpected, amountIn);

        uint256 tokenInBalanceAfter = balance(ct, DEFAULT_ADDRESS);
        uint256 tokenOutBalanceAfter = balance(tokenOut, DEFAULT_ADDRESS);

        assertEq(tokenInBalanceBefore - tokenInBalanceAfter, used);
        assertEq(tokenOutBalanceAfter - tokenOutBalanceBefore, tokenOutAmountOut);
        assertEq(tokenOutAmountOut, amountOutExpected);

        _verifyNoFunds(ct, address(router));
        _verifyNoFunds(address(ra), address(router));
        _verifyNoFunds(address(randomToken), address(router));
    }
}

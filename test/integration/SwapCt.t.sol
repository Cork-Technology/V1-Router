pragma solidity ^0.8.26;

// solhint-disable

import {TestBase} from "./../TestBase.sol";
import {DummyWETH} from "Depeg-swap/contracts/dummy/DummyWETH.sol";
import {ICommon} from "../../src/interfaces/ICommon.sol";
import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDsFlashSwapCore} from "Depeg-swap/contracts/interfaces/IDsFlashSwapRouter.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

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

    function testFuzzSwapRaCtExactInWithPermit(bool enableAggregator) external {
        vm.startPrank(DEFAULT_ADDRESS);
        randomToken.transfer(user, randomToken.balanceOf(DEFAULT_ADDRESS));
        ra.transfer(user, ra.balanceOf(DEFAULT_ADDRESS));
        vm.stopPrank();

        vm.startPrank(user);
        uint256 amountIn = 0.1 ether;

        // Approve tokens to Permit2
        randomToken.approve(address(permit2), amountIn);
        ra.approve(address(permit2), amountIn);

        address tokenIn = enableAggregator ? address(randomToken) : address(ra);
        address tokenOut = address(ra);

        ICommon.AggregatorParams memory AggregatorParams = defaultAggregatorParams(tokenIn, tokenOut, amountIn);

        // Create Permit2 permit
        (IAllowanceTransfer.PermitSingle memory permit, bytes memory signature) =
            createPermitAndSignature(tokenIn, amountIn, address(router), USER_KEY, address(permit2));

        uint256 tokenInBalanceBefore = balance(tokenIn, user);
        uint256 tokenOutBalanceBefore = balance(ct, user);

        // test slippage
        vm.expectRevert();
        router.swapRaForCtExactIn(AggregatorParams, defaultCurrencyId, 100000 ether, permit, signature);

        uint256 amountOut = router.swapRaForCtExactIn(AggregatorParams, defaultCurrencyId, 0, permit, signature);

        uint256 tokenInBalanceAfter = balance(tokenIn, user);
        uint256 tokenOutBalanceAfter = balance(ct, user);

        assertEq(tokenInBalanceBefore - tokenInBalanceAfter, amountIn);
        assertEq(tokenOutBalanceAfter - tokenOutBalanceBefore, amountOut);

        _verifyNoFunds(ct, address(router));
        _verifyNoFunds(address(ra), address(router));
        _verifyNoFunds(address(randomToken), address(router));
    }

    function testFuzzSwapRaCtExactOutWithPermit(bool enableAggregator) external {
        vm.startPrank(DEFAULT_ADDRESS);
        randomToken.transfer(user, randomToken.balanceOf(DEFAULT_ADDRESS));
        ra.transfer(user, ra.balanceOf(DEFAULT_ADDRESS));
        vm.stopPrank();

        vm.startPrank(user);

        // this what we approximately get for 0.1 RA
        uint256 amountOutExpected = 96e15;
        uint256 amountIn = 0.157 ether;

        // Approve tokens to Permit2
        randomToken.approve(address(permit2), amountIn);
        ra.approve(address(permit2), amountIn);

        address tokenIn = enableAggregator ? address(randomToken) : address(ra);
        address tokenOut = address(ra);

        uint256 tokenInBalanceBefore = balance(address(ra), user);
        uint256 tokenOutBalanceBefore = balance(ct, user);

        ICommon.AggregatorParams memory AggregatorParams = defaultAggregatorParams(tokenIn, tokenOut, amountIn);

        // Create Permit2 permit
        (IAllowanceTransfer.PermitSingle memory permit, bytes memory signature) =
            createPermitAndSignature(tokenIn, amountIn, address(router), USER_KEY, address(permit2));

        (uint256 used, uint256 remaining) =
            router.swapRaForCtExactOut(AggregatorParams, defaultCurrencyId, amountOutExpected, permit, signature);

        uint256 tokenInBalanceAfter = balance(address(ra), user);
        uint256 tokenOutBalanceAfter = balance(ct, user);

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

    function testFuzzSwapCtRaExactInWithPermit(bool enableAggregator) external {
        // First transfer some CT tokens to the user
        vm.startPrank(DEFAULT_ADDRESS);
        IERC20(ct).transfer(user, IERC20(ct).balanceOf(DEFAULT_ADDRESS) / 2);
        vm.stopPrank();

        vm.startPrank(user);
        uint256 amountIn = 0.1 ether;

        // Approve CT tokens to Permit2
        IERC20(ct).approve(address(permit2), amountIn);

        address tokenIn = address(ra);
        address tokenOut = enableAggregator ? address(randomToken) : address(ra);

        ICommon.AggregatorParams memory AggregatorParams = defaultAggregatorParams(tokenIn, tokenOut, amountIn);

        // Use the simplified SigUtil function
        (IAllowanceTransfer.PermitSingle memory permit, bytes memory signature) =
            createPermitAndSignature(ct, amountIn, address(router), USER_KEY, address(permit2));

        uint256 tokenInBalanceBefore = balance(ct, user);
        uint256 tokenOutBalanceBefore = balance(tokenOut, user);

        // test slippage
        vm.expectRevert();
        router.swapCtForRaExactIn(AggregatorParams, defaultCurrencyId, amountIn, 100000 ether, permit, signature);

        // use this without aggregator first to get the RA,
        // then we will revert the state so that we can test the aggregator with accurate RA
        snap();
        ICommon.AggregatorParams memory mockAggregatorParams = defaultAggregatorParams(tokenIn, tokenIn, 0);
        uint256 amountOut =
            router.swapCtForRaExactIn(AggregatorParams, defaultCurrencyId, amountIn, 0, permit, signature);
        restore();

        AggregatorParams.amountIn = amountOut;
        amountOut = router.swapCtForRaExactIn(AggregatorParams, defaultCurrencyId, amountIn, 0, permit, signature);

        uint256 tokenInBalanceAfter = balance(ct, user);
        uint256 tokenOutBalanceAfter = balance(tokenOut, user);

        assertEq(tokenInBalanceBefore - tokenInBalanceAfter, amountIn);
        assertEq(tokenOutBalanceAfter - tokenOutBalanceBefore, amountOut);

        _verifyNoFunds(ct, address(router));
        _verifyNoFunds(address(ra), address(router));
        _verifyNoFunds(address(randomToken), address(router));
    }

    function testFuzzSwapCtRaExactOutWithPermit(bool enableAggregator) external {
        // First transfer some CT tokens to the user
        vm.startPrank(DEFAULT_ADDRESS);
        IERC20(ct).transfer(user, IERC20(ct).balanceOf(DEFAULT_ADDRESS) / 2);
        vm.stopPrank();

        vm.startPrank(user);
        uint256 amountIn = 0.157 ether;
        uint256 amountOutExpected = 96e15;

        // Approve CT tokens to Permit2
        IERC20(ct).approve(address(permit2), amountIn);
        address tokenOut = enableAggregator ? address(randomToken) : address(ra);

        ICommon.AggregatorParams memory AggregatorParams =
            defaultAggregatorParams(address(ra), tokenOut, amountOutExpected);

        // Create Permit2 permit for CT tokens
        (IAllowanceTransfer.PermitSingle memory permit, bytes memory signature) =
            createPermitAndSignature(ct, amountIn, address(router), USER_KEY, address(permit2));

        uint256 tokenInBalanceBefore = balance(ct, user);
        uint256 tokenOutBalanceBefore = balance(tokenOut, user);

        (uint256 used, uint256 remaining, uint256 tokenOutAmountOut) = router.swapCtForRaExactOut(
            AggregatorParams, defaultCurrencyId, amountOutExpected, amountIn, permit, signature
        );

        uint256 tokenInBalanceAfter = balance(ct, user);
        uint256 tokenOutBalanceAfter = balance(tokenOut, user);

        assertEq(tokenInBalanceBefore - tokenInBalanceAfter, used);
        assertEq(tokenOutBalanceAfter - tokenOutBalanceBefore, tokenOutAmountOut);
        assertEq(tokenOutAmountOut, amountOutExpected);

        _verifyNoFunds(ct, address(router));
        _verifyNoFunds(address(ra), address(router));
        _verifyNoFunds(address(randomToken), address(router));
    }
}

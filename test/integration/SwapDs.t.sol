pragma solidity ^0.8.26;

// solhint-disable

import {TestBase} from "./../TestBase.sol";
import {DummyWETH} from "Depeg-swap/contracts/dummy/DummyWETH.sol";
import {ICommon} from "../../src/interfaces/ICommon.sol";
import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDsFlashSwapCore} from "Depeg-swap/contracts/interfaces/IDsFlashSwapRouter.sol";

contract SwapDs is TestBase {
    DummyWETH internal ra;
    DummyWETH internal pa;
    DummyWETH internal randomToken;

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

        // add liquidity
        moduleCore.depositLv(defaultCurrencyId, 10 ether, 0, 0);
        moduleCore.depositPsm(defaultCurrencyId, 10 ether);
    }

    function testFuzzSwapRaForDs(bool enableAggregator) external {
        uint256 amount = 1e18;

        ICommon.AggregatorParams memory AggregatorParams =
            defaultAggregatorParams(address(randomToken), address(ra), amount);

        AggregatorParams.enableAggregator = enableAggregator;

        if (!enableAggregator) {
            AggregatorParams.tokenIn = address(ra);
        }

        ICommon.SwapRaForDsParams memory params = ICommon.SwapRaForDsParams(
            defaultCurrencyId, 1, 0, defaultBuyApproxParams(), defaultOffchainGuessParams(), AggregatorParams
        );

        (address ct, address ds) = moduleCore.swapAsset(defaultCurrencyId, 1);

        uint256 balanceDsBefore = IERC20(ds).balanceOf(DEFAULT_ADDRESS);
        uint256 balanceCtBefore = IERC20(ct).balanceOf(DEFAULT_ADDRESS);

        IDsFlashSwapCore.SwapRaForDsReturn memory results = router.swapRaForDs(params);

        uint256 balanceDsAfter = IERC20(ds).balanceOf(DEFAULT_ADDRESS);
        uint256 balanceCtAfter = IERC20(ct).balanceOf(DEFAULT_ADDRESS);

        uint256 out = results.amountOut;
        uint256 refunded = results.ctRefunded;

        assertEq(out, balanceDsAfter - balanceDsBefore);
        assertEq(refunded, balanceCtAfter - balanceCtBefore);

        _verifyNoFunds(ct, address(router));
        _verifyNoFunds(ds, address(router));
        _verifyNoFunds(ra, address(router));
        _verifyNoFunds(pa, address(router));
    }

    function testFuzzSwapDsForRa(bool enableAggregator) external {
        uint256 amount = 1e18;

        ICommon.AggregatorParams memory AggregatorParams =
            defaultAggregatorParams(address(ra), address(randomToken), amount);

        AggregatorParams.enableAggregator = enableAggregator;

        {
            ICommon.AggregatorParams memory swapRaParams =
                defaultAggregatorParams(address(randomToken), address(ra), amount);

            if (!enableAggregator) {
                swapRaParams.tokenIn = address(ra);
            }

            ICommon.SwapRaForDsParams memory swapRa = ICommon.SwapRaForDsParams(
                defaultCurrencyId, 1, 0, defaultBuyApproxParams(), defaultOffchainGuessParams(), swapRaParams
            );
            IDsFlashSwapCore.SwapRaForDsReturn memory results = router.swapRaForDs(swapRa);
        }

        ICommon.SwapDsForRaParams memory params =
            ICommon.SwapDsForRaParams(defaultCurrencyId, 1, amount, 0, AggregatorParams);

        (address ct, address ds) = moduleCore.swapAsset(defaultCurrencyId, 1);
        allowFullAllowance(ds, address(router));

        uint256 balanceRaBefore = ra.balanceOf(DEFAULT_ADDRESS);
        uint256 balanceRandomTokenBefore = randomToken.balanceOf(DEFAULT_ADDRESS);

        params.amount = 0.1 ether;
        uint256 out = router.swapDsForRa(params);

        uint256 balanceRaAfter = ra.balanceOf(DEFAULT_ADDRESS);
        uint256 balanceRandomTokenAfter = randomToken.balanceOf(DEFAULT_ADDRESS);

        if (enableAggregator) {
            assertEq(out, balanceRandomTokenAfter - balanceRandomTokenBefore);
        } else {
            assertEq(out, balanceRaAfter - balanceRaBefore);
        }

        _verifyNoFunds(ct, address(router));
        _verifyNoFunds(ds, address(router));
        _verifyNoFunds(ra, address(router));
        _verifyNoFunds(pa, address(router));
    }
}

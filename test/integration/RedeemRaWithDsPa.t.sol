pragma solidity ^0.8.26;

// solhint-disable

import {TestBase} from "./../TestBase.sol";
import {DummyWETH} from "Depeg-swap/contracts/dummy/DummyWETH.sol";
import {ICorkSwapAggregator} from "../../src/interfaces/ICorkSwapAggregator.sol";
import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDsFlashSwapCore} from "Depeg-swap/contracts/interfaces/IDsFlashSwapRouter.sol";

contract RedeemRaWithDsPa is TestBase {
    DummyWETH internal ra;
    DummyWETH internal pa;
    DummyWETH internal randomToken;
    DummyWETH internal randomToken2;

    function setUp() public {
        initTests();
        vm.startPrank(DEFAULT_ADDRESS);

        randomToken = new DummyWETH();
        randomToken2 = new DummyWETH();

        (ra, pa,) = initializeAndIssueNewDs(10 days);

        bootstrapAggregatorLiquidity(ra);
        bootstrapAggregatorLiquidity(pa);
        bootstrapAggregatorLiquidity(randomToken);
        bootstrapAggregatorLiquidity(randomToken2);

        bootstrapSelfLiquidity(ra);
        bootstrapSelfLiquidity(pa);
        bootstrapSelfLiquidity(randomToken);
        bootstrapSelfLiquidity(randomToken2);

        allowFullAllowance(address(randomToken), address(router));
        allowFullAllowance(address(randomToken2), address(router));
        allowFullAllowance(address(ra), address(router));
        allowFullAllowance(address(pa), address(router));
        allowFullAllowance(address(ra), address(moduleCore));
        allowFullAllowance(address(pa), address(moduleCore));

        // add liquidity
        moduleCore.depositLv(defaultCurrencyId, 10 ether, 0, 0);
        moduleCore.depositPsm(defaultCurrencyId, 10 ether);
    }

    // we'll test it like a black box
    // i.e we use a set amount of DS and random token and we should get
    // some amount of ra or random token 2 as output while verifying there's no fund stuck in the router
    function testFuzzRedeemRaWithDs(bool enableZapIn, bool enableZapOut) external {
        // steps:
        // 1. if zap in we provide some amount of random token else just pure PA
        // 2. we provide also an equal or greater amount of DS
        // 3. if zap out, we use the RA ouput from redeeming as amount(for simplicity sake we'll use 1:1 rate)
        // 4. in the end we should get the same amount of randomtoken2 or RA as output
        uint256 amount = 0.1 ether;

        address zapInInputToken = enableZapIn ? address(randomToken) : address(pa);
        address zapOutOutputToken = enableZapOut ? address(randomToken2) : address(ra);

        ICorkSwapAggregator.AggregatorParams memory zapInParams =
            defaultAggregatorParams(zapInInputToken, address(pa), amount);
        ICorkSwapAggregator.AggregatorParams memory zapOutParams =
            defaultAggregatorParams(address(ra), zapOutOutputToken, amount);
        (address ct, address ds) = moduleCore.swapAsset(defaultCurrencyId, 1);

        uint256 dsBalanceBefore = balance(ds, DEFAULT_ADDRESS);
        uint256 zapOutBalanceBefore = balance(zapOutOutputToken, DEFAULT_ADDRESS);

        allowFullAllowance(ds, address(router));
        // remove the fee so that we can get accurate results
        corkConfig.updatePsmBaseRedemptionFeePercentage(defaultCurrencyId, 0);
        (uint256 dsUsed, uint256 outAmount) =
            router.redeemRaWithDsPa(zapInParams, zapOutParams, defaultCurrencyId, amount + 4 ether);

        uint256 dsBalanceAfter = balance(ds, DEFAULT_ADDRESS);
        uint256 zapOutBalanceAfter = balance(zapOutOutputToken, DEFAULT_ADDRESS);

        assertEq(dsUsed, amount);
        assertEq(outAmount, amount);
        assertEq(dsBalanceBefore - dsBalanceAfter, dsUsed);
        assertEq(zapOutBalanceAfter - zapOutBalanceBefore, outAmount);
    }
}

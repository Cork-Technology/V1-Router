pragma solidity 0.8.26;

// solhint-disable

import {TestBase} from "./../TestBase.sol";
import {DummyWETH} from "Depeg-swap/contracts/dummy/DummyWETH.sol";
import {ICommon} from "../../src/interfaces/ICommon.sol";
import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDsFlashSwapCore} from "Depeg-swap/contracts/interfaces/IDsFlashSwapRouter.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

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

        address zapOutOutputToken;
        ICommon.AggregatorParams memory zapInParams;
        ICommon.AggregatorParams memory zapOutParams;
        {
            address zapInInputToken = enableZapIn ? address(randomToken) : address(pa);
            zapInParams = defaultAggregatorParams(zapInInputToken, address(pa), amount);
        }
        zapOutOutputToken = enableZapOut ? address(randomToken2) : address(ra);
        zapOutParams = defaultAggregatorParams(address(ra), zapOutOutputToken, amount);
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

    function testFuzzRedeemRaWithDsPermit(bool enableZapIn, bool enableZapOut) external {
        vm.startPrank(DEFAULT_ADDRESS);
        randomToken.transfer(user, 10 ether);
        randomToken2.transfer(user, 10 ether);
        pa.transfer(user, 10 ether);

        // Also transfer some DS tokens to the user
        (address ct, address ds) = moduleCore.swapAsset(defaultCurrencyId, 1);
        router.depositPsm(defaultAggregatorParams(address(randomToken), address(ra), 5 ether), defaultCurrencyId);
        IERC20(ds).transfer(user, IERC20(ds).balanceOf(DEFAULT_ADDRESS));

        // remove the fee so that we can get accurate results
        corkConfig.updatePsmBaseRedemptionFeePercentage(defaultCurrencyId, 0);
        vm.stopPrank();

        vm.startPrank(user);
        // Approve tokens to Permit2
        uint256 amount = 0.1 ether;
        IERC20(ds).approve(address(permit2), amount + 4 ether);
        randomToken.approve(address(permit2), amount);
        pa.approve(address(permit2), amount);

        address zapOutOutputToken = enableZapOut ? address(randomToken2) : address(ra);

        uint256 dsBalanceBefore = IERC20(ds).balanceOf(user);
        uint256 zapOutBalanceBefore = balance(zapOutOutputToken, user);

        IAllowanceTransfer.PermitBatch memory permit;
        bytes memory signature;
        {
            // Setup batch permit for DS and input token
            address[] memory tokens = new address[](2);
            uint256[] memory amounts = new uint256[](2);
            tokens[0] = ds;
            tokens[1] = enableZapIn ? address(randomToken) : address(pa);
            amounts[0] = amount + 4 ether; // DS amount
            amounts[1] = amount; // Input token amount

            (permit, signature) =
                createBatchPermitAndSignature(tokens, amounts, address(router), USER_KEY, address(permit2));
        }

        {
            ICommon.AggregatorParams memory zapInParams =
                defaultAggregatorParams(enableZapIn ? address(randomToken) : address(pa), address(pa), amount);
            ICommon.AggregatorParams memory zapOutParams =
                defaultAggregatorParams(address(ra), zapOutOutputToken, amount);
            (uint256 dsUsed, uint256 outAmount) = router.redeemRaWithDsPa(
                zapInParams, zapOutParams, defaultCurrencyId, amount + 4 ether, permit, signature
            );

            assertEq(dsUsed, amount);
            assertEq(outAmount, amount);
        }

        uint256 dsBalanceAfter = IERC20(ds).balanceOf(user);
        uint256 zapOutBalanceAfter = balance(zapOutOutputToken, user);

        assertEq(dsBalanceBefore - dsBalanceAfter, amount);
        assertEq(zapOutBalanceAfter - zapOutBalanceBefore, amount);

        // Verify no tokens are left in the router
        _verifyNoFunds(ds, address(router));
        _verifyNoFunds(enableZapIn ? address(randomToken) : address(pa), address(router));
        _verifyNoFunds(zapOutOutputToken, address(router));
        _verifyNoFunds(address(ra), address(router));
    }
}

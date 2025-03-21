pragma solidity ^0.8.26;

import {TestBase} from "./../TestBase.sol";
import {DummyWETH} from "Depeg-swap/contracts/dummy/DummyWETH.sol";
import {ICommon} from "../../src/interfaces/ICommon.sol";
import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAllowanceTransfer} from "permit2/interfaces/IAllowanceTransfer.sol";
import {ICorkRouterV1} from "../../src/interfaces/ICorkRouterV1.sol";

contract Repurchase is TestBase {
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
    }

    function testRepurchase() external {
        // for simplicity sake
        corkConfig.updateRepurchaseFeeRate(defaultCurrencyId, 0);

        uint256 amount = 1e18;

        router.depositPsm(defaultAggregatorParams(address(randomToken), address(ra), amount), defaultCurrencyId);

        (, address ds) = moduleCore.swapAsset(defaultCurrencyId, 1);

        allowFullAllowance(ds, address(moduleCore));
        moduleCore.redeemRaWithDsPa(defaultCurrencyId, 1, amount);

        uint256 dsBalanceBefore = IERC20(ds).balanceOf(DEFAULT_ADDRESS);
        uint256 paBalanceBefore = pa.balanceOf(DEFAULT_ADDRESS);

        router.repurchase(defaultAggregatorParams(address(randomToken), address(ra), amount), defaultCurrencyId, amount);

        uint256 dsBalanceAfter = IERC20(ds).balanceOf(DEFAULT_ADDRESS);
        uint256 paBalanceAfter = pa.balanceOf(DEFAULT_ADDRESS);

        assertEq(amount, dsBalanceAfter - dsBalanceBefore);
        assertEq(amount, paBalanceAfter - paBalanceBefore);
    }

    function testFuzzRepurchase(bool enableAggregator) external {
        // for simplicity sake
        corkConfig.updateRepurchaseFeeRate(defaultCurrencyId, 0);

        uint256 amount = 1e18;

        address token = enableAggregator ? address(randomToken) : address(ra);

        ICommon.AggregatorParams memory params = defaultAggregatorParams(token, address(ra), amount);
        params.enableAggregator = enableAggregator;

        router.depositPsm(params, defaultCurrencyId);

        (, address ds) = moduleCore.swapAsset(defaultCurrencyId, 1);

        allowFullAllowance(ds, address(moduleCore));
        moduleCore.redeemRaWithDsPa(defaultCurrencyId, 1, amount);

        uint256 dsBalanceBefore = IERC20(ds).balanceOf(DEFAULT_ADDRESS);
        uint256 paBalanceBefore = pa.balanceOf(DEFAULT_ADDRESS);

        router.repurchase(params, defaultCurrencyId, amount);

        uint256 dsBalanceAfter = IERC20(ds).balanceOf(DEFAULT_ADDRESS);
        uint256 paBalanceAfter = pa.balanceOf(DEFAULT_ADDRESS);

        assertEq(amount, dsBalanceAfter - dsBalanceBefore);
        assertEq(amount, paBalanceAfter - paBalanceBefore);
    }

    function testRepurchaseWithPermit() public {
        // for simplicity sake
        corkConfig.updateRepurchaseFeeRate(defaultCurrencyId, 0);

        vm.startPrank(DEFAULT_ADDRESS);
        uint256 amount = 1e18;
        Id id = defaultCurrencyId;

        randomToken.transfer(user, amount);

        // We need to prepare the system first - using the normal account to create DS
        router.depositPsm(defaultAggregatorParams(address(randomToken), address(ra), amount), defaultCurrencyId);

        (, address ds) = moduleCore.swapAsset(defaultCurrencyId, 1);

        allowFullAllowance(ds, address(moduleCore));
        moduleCore.redeemRaWithDsPa(defaultCurrencyId, 1, amount);
        vm.stopPrank();

        // Now back to testing with the user
        vm.startPrank(user);
        randomToken.approve(address(permit2), amount);
        ICommon.AggregatorParams memory params = defaultAggregatorParams(address(randomToken), address(ra), amount);

        // Create a PermitSingle for the token approval
        (IAllowanceTransfer.PermitSingle memory permit, bytes memory signature) =
            createPermitAndSignature(params.tokenIn, params.amountIn, address(router), USER_KEY, address(permit2));

        uint256 dsBalanceBefore = IERC20(ds).balanceOf(user);
        uint256 paBalanceBefore = pa.balanceOf(user);

        router.repurchase(params, id, amount, permit, signature);

        uint256 dsBalanceAfter = IERC20(ds).balanceOf(user);
        uint256 paBalanceAfter = pa.balanceOf(user);

        assertEq(amount, dsBalanceAfter - dsBalanceBefore);
        assertEq(amount, paBalanceAfter - paBalanceBefore);
    }
}

pragma solidity ^0.8.26;

import {TestBase} from "./../TestBase.sol";
import {DummyWETH} from "Depeg-swap/contracts/dummy/DummyWETH.sol";
import {ICorkSwapAggregator} from "../../src/interfaces/ICorkSwapAggregator.sol";
import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
        allowFullAllowance(address(ra), address(moduleCore));
        allowFullAllowance(address(pa), address(moduleCore));
    }

    function testRepurchase() external {
        // for simplicity sake
        corkConfig.updateRepurchaseFeeRate(defaultCurrencyId, 0);

        uint256 amount = 1e18;

        router.depositPsm(defaultSwapParams(address(randomToken), address(ra), amount), defaultCurrencyId);

        (, address ds) = moduleCore.swapAsset(defaultCurrencyId, 1);
        allowFullAllowance(ds, address(moduleCore));
        moduleCore.redeemRaWithDsPa(defaultCurrencyId, 1, amount);

        uint256 dsBalanceBefore = IERC20(ds).balanceOf(DEFAULT_ADDRESS);
        uint256 paBalanceBefore = pa.balanceOf(DEFAULT_ADDRESS);
        (, uint256 receivedPa, uint256 receivedDs,,,) =
            router.repurchase(defaultSwapParams(address(randomToken), address(ra), amount), defaultCurrencyId, amount);
        uint256 dsBalanceAfter = IERC20(ds).balanceOf(DEFAULT_ADDRESS);
        uint256 paBalanceAfter = pa.balanceOf(DEFAULT_ADDRESS);

        assertEq(amount, dsBalanceAfter - dsBalanceBefore);
        assertEq(amount, paBalanceAfter - paBalanceBefore);
    }
}

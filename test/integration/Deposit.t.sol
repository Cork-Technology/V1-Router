pragma solidity ^0.8.26;

import {TestBase} from "./../TestBase.sol";
import {DummyWETH} from "Depeg-swap/contracts/dummy/DummyWETH.sol";
import {ICorkSwapAggregator} from "../../src/interfaces/ICorkSwapAggregator.sol";
import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Deposit is TestBase {
    DummyWETH internal ra;
    DummyWETH internal randomToken;

    function setUp() public {
        initTests();
        vm.startPrank(DEFAULT_ADDRESS);

        randomToken = new DummyWETH();

        (ra,,) = initializeAndIssueNewDs(10 days);

        bootstrapAggregatorLiquidity(ra);
        bootstrapAggregatorLiquidity(randomToken);

        bootstrapSelfLiquidity(ra);
    }

    function testDepositPsm() public {
        uint256 amount = 1e18;

        ICorkSwapAggregator.SwapParams memory params = defaultSwapParams(address(randomToken), address(ra), amount);

        Id id = defaultCurrencyId;

        uint256 received = router.depositPsm(params, id);

        // verify that router has no funds
        assertEq(ra.balanceOf(address(router)), 0);

        (address ct, address ds) = moduleCore.swapAsset(id, 1);
        assertEq(IERC20(ct).balanceOf(address(router)), 0);
        assertGt(IERC20(ds).balanceOf(address(router)), 0);

        // verify that we receive ct and ds
        assertEq(IERC20(ct).balanceOf(DEFAULT_ADDRESS), received);
        assertEq(IERC20(ds).balanceOf(DEFAULT_ADDRESS), received);
    }
}

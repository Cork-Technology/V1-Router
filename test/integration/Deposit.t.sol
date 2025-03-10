pragma solidity ^0.8.26;

import {TestBase} from "./../TestBase.sol";
import {DummyWETH} from "Depeg-swap/contracts/dummy/DummyWETH.sol";
import {ICommon} from "../../src/interfaces/ICommon.sol";
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
        bootstrapSelfLiquidity(randomToken);

        allowFullAllowance(address(randomToken), address(router));
        allowFullAllowance(address(ra), address(router));
    }

    function testDepositPsm() public {
        uint256 amount = 1e18;

        ICommon.AggregatorParams memory params =
            defaultAggregatorParams(address(randomToken), address(ra), amount);

        Id id = defaultCurrencyId;

        uint256 received = router.depositPsm(params, id);

        // verify that router has no funds
        assertEq(ra.balanceOf(address(router)), 0);

        (address ct, address ds) = moduleCore.swapAsset(id, 1);
        assertEq(IERC20(ct).balanceOf(address(router)), 0);
        assertEq(IERC20(ds).balanceOf(address(router)), 0);

        // verify that we receive ct and ds
        assertEq(IERC20(ct).balanceOf(DEFAULT_ADDRESS), received);
        assertEq(IERC20(ds).balanceOf(DEFAULT_ADDRESS), received);
    }

    function testDepositLv() public {
        uint256 amount = 1e18;

        ICommon.AggregatorParams memory params =
            defaultAggregatorParams(address(randomToken), address(ra), amount);

        Id id = defaultCurrencyId;

        uint256 received = router.depositLv(params, id, 0, 0);

        // verify that router has no funds
        assertEq(ra.balanceOf(address(router)), 0);
        assertEq(IERC20(randomToken).balanceOf(address(router)), 0);

        // verify that we receive lv`
        address lv = moduleCore.lvAsset(id);

        assertEq(IERC20(lv).balanceOf(DEFAULT_ADDRESS), received);
    }

    function testFuzzDepositPsm(bool enableAggregator) public {
        uint256 amount = 1e18;

        ICommon.AggregatorParams memory params =
            defaultAggregatorParams(address(randomToken), address(ra), amount);
        params.enableAggregator = enableAggregator;

        if (!enableAggregator) {
            params.tokenIn = address(ra);
        }

        Id id = defaultCurrencyId;

        uint256 received = router.depositPsm(params, id);

        // verify that router has no funds
        assertEq(ra.balanceOf(address(router)), 0);

        (address ct, address ds) = moduleCore.swapAsset(id, 1);
        assertEq(IERC20(ct).balanceOf(address(router)), 0);
        assertEq(IERC20(ds).balanceOf(address(router)), 0);

        // verify that we receive ct and ds
        assertEq(IERC20(ct).balanceOf(DEFAULT_ADDRESS), received);
        assertEq(IERC20(ds).balanceOf(DEFAULT_ADDRESS), received);
    }

    function testFuzzDepositLv(bool enableAggregator) public {
        uint256 amount = 1e18;

        ICommon.AggregatorParams memory params =
            defaultAggregatorParams(address(randomToken), address(ra), amount);
        params.enableAggregator = enableAggregator;

        if (!enableAggregator) {
            params.tokenIn = address(ra);
        }

        Id id = defaultCurrencyId;

        uint256 received = router.depositLv(params, id, 0, 0);

        // verify that router has no funds
        assertEq(ra.balanceOf(address(router)), 0);
        assertEq(IERC20(randomToken).balanceOf(address(router)), 0);

        // verify that we receive lv`
        address lv = moduleCore.lvAsset(id);

        assertEq(IERC20(lv).balanceOf(DEFAULT_ADDRESS), received);
    }
}

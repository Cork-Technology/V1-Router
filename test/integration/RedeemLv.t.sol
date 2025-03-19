pragma solidity ^0.8.26;

// solhint-disable

import {TestBase} from "./../TestBase.sol";
import {DummyWETH} from "Depeg-swap/contracts/dummy/DummyWETH.sol";
import {ICommon} from "../../src/interfaces/ICommon.sol";
import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Withdrawal} from "Depeg-swap/contracts/core/Withdrawal.sol";
import {IVault} from "Depeg-swap/contracts/interfaces/IVault.sol";
import {Asset} from "Depeg-swap/contracts/core/assets/Asset.sol";

contract RedeemLv is TestBase {
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
        allowFullAllowance(address(ra), address(flashSwapRouter));
        allowFullAllowance(address(pa), address(router));
    }

    function testRedeemLvExpired() external {
        uint256 amount = 1e18;

        ICommon.AggregatorParams memory params = defaultAggregatorParams(address(randomToken), address(ra), amount);

        Id id = defaultCurrencyId;

        // disable ct split so we get accurate result
        corkConfig.updateLvStrategyCtSplitPercentage(id, 0);

        // deposit some lv and psm
        router.depositLv(params, id, 0, 0);
        router.depositPsm(params, id);

        params = defaultAggregatorParams(address(pa), address(ra), amount);

        // redeem some ds + pa so that we got some pa
        uint256 redeemAmount = 1e18;

        (, address ds) = moduleCore.swapAsset(id, 1);

        allowFullAllowance(ds, address(moduleCore));
        allowFullAllowance(address(pa), address(moduleCore));

        moduleCore.redeemRaWithDsPa(id, 1, redeemAmount);

        // ff to expired so that lv can get pa
        uint256 expired = Asset(ds).expiry();

        vm.warp(expired);

        // redeem lv with router
        address lv = moduleCore.lvAsset(id);
        allowFullAllowance(lv, address(moduleCore));

        IVault.RedeemEarlyParams memory redeemEarlyParams =
            IVault.RedeemEarlyParams(id, amount, 0, block.timestamp, 0, 0, 0);

        IVault.RedeemEarlyResult memory result = moduleCore.redeemEarlyLv(redeemEarlyParams);

        ICommon.LvRedeemParams memory routerData = ICommon.LvRedeemParams(
            DEFAULT_ADDRESS, id, 0, defaultAggregatorParams(address(pa), address(ra), 333444370419713515)
        );

        vm.warp(block.timestamp + 3 days);

        uint256 raBalanceBefore = ra.balanceOf(DEFAULT_ADDRESS);

        withdrawalContract.claimRouted(result.withdrawalId, address(router), abi.encode(routerData));

        uint256 raBalanceAfter = ra.balanceOf(DEFAULT_ADDRESS);

        // because of the fee
        assertApproxEqAbs(1e18, raBalanceAfter - raBalanceBefore, 1e17);
    }

    function testRedeemLvActiveSellDs() external {
        uint256 amount = 1e18;

        ICommon.AggregatorParams memory params = defaultAggregatorParams(address(randomToken), address(ra), amount);

        Id id = defaultCurrencyId;

        // disable ct split so we get accurate result
        corkConfig.updateLvStrategyCtSplitPercentage(id, 0);

        // deposit some lv and psm
        router.depositLv(params, id, 0, 0);

        params = defaultAggregatorParams(address(pa), address(ra), amount);

        // redeem lv with router
        address lv = moduleCore.lvAsset(id);
        allowFullAllowance(lv, address(moduleCore));

        IVault.RedeemEarlyParams memory redeemEarlyParams =
            IVault.RedeemEarlyParams(id, amount, 0, block.timestamp, 0, 0, 0);

        IVault.RedeemEarlyResult memory result = moduleCore.redeemEarlyLv(redeemEarlyParams);

        ICommon.LvRedeemParams memory routerData =
            ICommon.LvRedeemParams(DEFAULT_ADDRESS, id, 0, defaultAggregatorParams(address(pa), address(ra), 0));

        vm.warp(block.timestamp + 3 days);

        uint256 raBalanceBefore = ra.balanceOf(DEFAULT_ADDRESS);

        withdrawalContract.claimRouted(result.withdrawalId, address(router), abi.encode(routerData));

        uint256 raBalanceAfter = ra.balanceOf(DEFAULT_ADDRESS);

        // because of the amm liquidity lock we will get slight less
        assertApproxEqAbs(1e18, raBalanceAfter - raBalanceBefore, 1e5);
    }

    function testRedeemLvActiveSellCt() external {
        uint256 amount = 10e18;

        ICommon.AggregatorParams memory params = defaultAggregatorParams(address(randomToken), address(ra), amount);

        Id id = defaultCurrencyId;

        // disable ct split so we get accurate result
        corkConfig.updateLvStrategyCtSplitPercentage(id, 0);

        // deposit some lv and psm
        router.depositLv(params, id, 0, 0);

        // buy a little bit of ds so that we can test selling ct
        flashSwapRouter.swapRaforDs(id, 1, 0.0001 ether, 0, defaultBuyApproxParams(), defaultOffchainGuessParams());

        params = defaultAggregatorParams(address(pa), address(ra), amount);

        // redeem lv with router
        address lv = moduleCore.lvAsset(id);
        allowFullAllowance(lv, address(moduleCore));

        IVault.RedeemEarlyParams memory redeemEarlyParams =
            IVault.RedeemEarlyParams(id, 1e18, 0, block.timestamp, 0, 0, 0);

        IVault.RedeemEarlyResult memory result = moduleCore.redeemEarlyLv(redeemEarlyParams);

        ICommon.LvRedeemParams memory routerData =
            ICommon.LvRedeemParams(DEFAULT_ADDRESS, id, 0, defaultAggregatorParams(address(pa), address(ra), 0));

        vm.warp(block.timestamp + 3 days);

        uint256 raBalanceBefore = ra.balanceOf(DEFAULT_ADDRESS);

        withdrawalContract.claimRouted(result.withdrawalId, address(router), abi.encode(routerData));

        uint256 raBalanceAfter = ra.balanceOf(DEFAULT_ADDRESS);

        // because of the amm liquidity lock we will get slight less and the price of ct is less because we bought DS
        assertApproxEqAbs(1e18, raBalanceAfter - raBalanceBefore, 0.0001 ether);

        (address ct, address ds) = moduleCore.swapAsset(id, 1);

        _verifyNoFunds(address(ra), address(router));
        _verifyNoFunds(address(pa), address(router));
        _verifyNoFunds(address(ct), address(router));
        _verifyNoFunds(address(ds), address(router));
    }
}

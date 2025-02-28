pragma solidity ^0.8.26;

// solhint-disable

import {TestBase} from "./../TestBase.sol";
import {DummyWETH} from "Depeg-swap/contracts/dummy/DummyWETH.sol";
import {ICorkSwapAggregator} from "../../src/interfaces/ICorkSwapAggregator.sol";
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
        allowFullAllowance(address(pa), address(router));
    }

    function testRedeemLvExpired() external {
        uint256 amount = 1e18;

        ICorkSwapAggregator.SwapParams memory params = defaultSwapParams(address(randomToken), address(ra), amount);

        Id id = defaultCurrencyId;

        // deposit some lv and psm
        router.depositLv(params, id, 0, 0);
        router.depositPsm(params, id);

        params = defaultSwapParams(address(pa), address(ra), amount);

        // redeem some ds + pa so that we got some pa
        uint256 redeemAmount = 5e17;

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

        ICorkSwapAggregator.RouterParams memory routerData =
            ICorkSwapAggregator.RouterParams(id, 0, defaultSwapParams(address(pa), address(ra), result.paReceived));

        vm.warp(block.timestamp + 3 days);

        withdrawalContract.claimRouted(result.withdrawalId, address(router), abi.encode(routerData));
        // TODO add more detailed assertments
    }

    // TODO add test that also test while active
}

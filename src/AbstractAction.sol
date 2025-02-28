// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IPSMcore} from "Depeg-swap/contracts/interfaces/IPSMcore.sol";
import {IVault} from "Depeg-swap/contracts/interfaces/IVault.sol";
import {Initialize} from "Depeg-swap/contracts/interfaces/Init.sol";
import {IPoolManager} from "v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";
import {IDsFlashSwapCore} from "Depeg-swap/contracts/interfaces/IDsFlashSwapRouter.sol";

import {ICorkHook} from "Cork-Hook/interfaces/ICorkHook.sol";
import {PoolKey} from "v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import {State} from "./State.sol";
import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {TransferHelper} from "./lib/TransferHelper.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ERC20Burnable} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ICorkSwapAggregator} from "./interfaces/ICorkSwapAggregator.sol";
import {IWithdrawalRouter} from "Depeg-swap/contracts/interfaces/IWithdrawalRouter.sol";
import {Asset} from "Depeg-swap/contracts/core/assets/Asset.sol";
import {Constants} from "Cork-Hook/Constants.sol";
import {Currency} from "v4-periphery/lib/v4-core/src/types/Currency.sol";
import {CurrencySettler} from "v4-periphery/lib/v4-core/test/utils/CurrencySettler.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "v4-periphery/lib/v4-core/src/types/BalanceDelta.sol";

abstract contract AbtractAction is State {
    function _transferFromUser(address token, uint256 amount) internal {
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amount);
    }

    function _increaseAllowanceForProtocol(address token, uint256 amount) internal {
        _increaseAllowance(token, CORE, amount);
    }

    function _increaseAllowance(address token, address to, uint256 amount) internal {
        TransferHelper.safeApprove(token, to, amount);
    }

    function _transferToUser(address token, uint256 amount) internal {
        TransferHelper.safeTransfer(token, msg.sender, amount);
    }

    function _transfer(address token, address to, uint256 amount) internal {
        TransferHelper.safeTransfer(token,to,amount);
    }

    function _contractBalance(address token) internal view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function _transferAllCtDsToUser(Id id) internal {
        (address ct, address ds) = __getCtDs(id);

        _transferToUser(ct, _contractBalance(ct));
        _transferToUser(ds, _contractBalance(ds));
    }

    function _transferAllLvToUser(Id id) internal {
        address lv = _vault().lvAsset(id);

        _transferToUser(lv, _contractBalance(lv));
    }

    function __getCtDs(Id id) internal view returns (address ct, address ds) {
        Initialize core = Initialize(CORE);
        uint256 dsId = core.lastDsId(id);
        (ct, ds) = __getCtDs(id, dsId);
    }

    function __getRaPair(Id id) internal view returns (address ra, address pa) {
        Initialize core = Initialize(CORE);
        (ra, pa) = core.underlyingAsset(id);
    }

    function __getCtDs(Id id, uint256 dsId) internal view returns (address ct, address ds) {
        Initialize core = Initialize(CORE);

        (ct, ds) = core.swapAsset(id, dsId);
    }

    function _swap(ICorkSwapAggregator.SwapParams memory params) internal returns (uint256) {
        _transferFromUser(params.tokenIn, params.amountIn);
        return _swapNoTransfer(params);
    }

    function _swapNoTransfer(ICorkSwapAggregator.SwapParams memory params) internal returns (uint256) {
        _increaseAllowance(params.tokenIn, params.extRouter, params.amountIn);
        return ICorkSwapAggregator(params.extRouter).swap(params);
    }

    function __findCtDsFromTokens(IWithdrawalRouter.Tokens[] calldata tokens, Id id)
        internal
        view
        returns (address ct, address ds, uint256 dsId)
    {
        for (uint256 i = 0; i < tokens.length; i++) {
            try Asset(tokens[i].token).dsId() returns (uint256 _dsId) {
                dsId = _dsId;
                (ct, ds) = __getCtDs(id, dsId);

                return (ct, ds, dsId);

                // solhint-disable-next-line no-empty-blocks
            } catch {}
        }
        // TODO : move to interface as custom errors
        revert("Invalid tokens");
    }

    function _handleLvRedeemDsExpired(Id id, address ct, address ds, uint256 dsId) internal {
        ERC20Burnable(ds).burn(_contractBalance(ds));

        _increaseAllowanceForProtocol(ct, _contractBalance(ct));

        _psm().redeemWithExpiredCt(id, dsId, _contractBalance(ct));
    }

    function _handleLvRedeem(IWithdrawalRouter.Tokens[] calldata tokens, bytes calldata params) internal {
        ICorkSwapAggregator.RouterParams memory routerParams = abi.decode(params, (ICorkSwapAggregator.RouterParams));

        (address ct, address ds, uint256 dsId) = __findCtDsFromTokens(tokens, routerParams.id);
        (address ra, address pa) = __getRaPair(routerParams.id);

        if (Asset(ct).isExpired()) {
            _handleLvRedeemDsExpired(routerParams.id, ct, ds, dsId);
        } else {
            _handleLvRedeemDsActive(routerParams.id, ct, ds, dsId, routerParams.dsMinOut, routerParams.receiver);
        }

        _swapNoTransfer(routerParams.paSwapAggregatorData);

        _transfer(ra, routerParams.receiver, _contractBalance(ra));
        _transfer(pa, routerParams.receiver, _contractBalance(pa));
    }

    function _handleLvRedeemDsActive(Id id, address ct, address ds, uint256 dsId, uint256 amountOutMin, address user)
        internal
    {
        uint256 redeemAmount;
        bool isCt;
        uint256 diff;

        {
            uint256 ctBalance = _contractBalance(ct);
            uint256 dsBalance = _contractBalance(ds);

            (redeemAmount, isCt, diff) = ctBalance > dsBalance
                ? (dsBalance, true, ctBalance - dsBalance)
                : (ctBalance, false, dsBalance - ctBalance);
        }
        _increaseAllowanceForProtocol(ct, redeemAmount);
        _increaseAllowanceForProtocol(ds, redeemAmount);
        _psm().returnRaWithCtDs(id, redeemAmount);

        (address ra,) = __getRaPair(id);

        // sell remaining CT or DS
        if (isCt) {
            _increaseAllowance(ct, HOOK, diff);

            IPoolManager manager = IPoolManager(_hook().getPoolManager());
            bytes memory raw;
            {
                PoolKey memory key = _hook().getPoolKey(ra, ct);
                // we want to swap ct for ra
                // so if ra is less than ct that means
                // ra is token0 and ct is token1 -> false
                // else -> true
                bool zeroForOne = ra < ct ? false : true;

                IPoolManager.SwapParams memory swapParams =
                    IPoolManager.SwapParams(zeroForOne, -int256(diff), Constants.SQRT_PRICE_1_1);
                raw = abi.encode(key, swapParams, ct, ra);
            }

            // unlock and init swap
            // will just transfer the ct to user if it fails to swap
            try manager.unlock(raw) {}
            catch {
                _transfer(ct, user, _contractBalance(ct));
            }
        } else {
            _increaseAllowance(ds, FLASH_SWAP_ROUTER, diff);
            IDsFlashSwapCore flashswapRouter = _flashSwapRouter();

            // we essentially just give back the token to user if there's if for some reason
            // we fail to sell the DS
            // solhin-disable-next-line
            try flashswapRouter.swapDsforRa(id, dsId, diff, amountOutMin) returns (uint256) {}
            catch {
                _transfer(ds, user, _contractBalance(ct));
            }
        }
    }

    function unlockCallback(bytes calldata rawData) external returns (bytes memory) {
        address manager = _hook().getPoolManager();

        if (msg.sender != manager) {
            // TODO : move to custom error
            revert("only manager");
        }

        (PoolKey memory key, IPoolManager.SwapParams memory params, address _ct, address _ra) =
            abi.decode(rawData, (PoolKey, IPoolManager.SwapParams, address, address));

        // no flash swaps
        BalanceDelta delta = IPoolManager(manager).swap(key, params, bytes(""));

        Currency ct = Currency.wrap(_ct);
        Currency ra = Currency.wrap(_ra);

        uint256 settleAmount = uint256(-params.amountSpecified);

        // we basically brute force the delta
        // since if it's the same as we specified, then the other one must be the swap output
        // we don't need to revers(-) the number since if it's owed to us, the number will always be positive
        uint256 takeAmount = BalanceDeltaLibrary.amount0(delta) == params.amountSpecified
            ? uint256(uint128(BalanceDeltaLibrary.amount1(delta)))
            : uint256(uint128(BalanceDeltaLibrary.amount0(delta)));

        CurrencySettler.settle(ct, IPoolManager(manager), address(this), settleAmount, false);
        CurrencySettler.take(ra, IPoolManager(manager), address(this), takeAmount, false);
    }
}

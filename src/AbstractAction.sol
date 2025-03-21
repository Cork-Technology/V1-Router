// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Initialize} from "Depeg-swap/contracts/interfaces/Init.sol";
import {IPoolManager} from "v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";
import {IDsFlashSwapCore} from "Depeg-swap/contracts/interfaces/IDsFlashSwapRouter.sol";
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

abstract contract AbstractAction is State {
    function _validateParams(AggregatorParams memory params) internal view {
        if (params.enableAggregator) {
            return;
        }

        if (params.tokenIn != params.tokenOut) {
            revert InvalidTokens();
        }
    }

    // solidity just straight up refused to work when we overload this
    function _validateParamsCalldata(AggregatorParams calldata params) internal view {
        if (params.enableAggregator) {
            return;
        }

        if (params.tokenIn != params.tokenOut) {
            revert InvalidTokens();
        }
    }

    function _transferFromUser(address token, uint256 amount) internal {
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amount);
    }

    function _transferFromUserWithPermit(address token, uint256 amount) internal {
        _permit2().transferFrom(msg.sender, address(this), uint160(amount), token);
    }

    function _increaseAllowanceForProtocol(address token, uint256 amount) internal {
        _increaseAllowance(token, core, amount);
    }

    function _increaseAllowanceForRouter(address token, uint256 amount) internal {
        _increaseAllowance(token, flashSwapRouter, amount);
    }

    function _increaseAllowance(address token, address to, uint256 amount) internal {
        TransferHelper.safeApprove(token, to, amount);
    }

    function _transferToUser(address token, uint256 amount) internal {
        TransferHelper.safeTransfer(token, msg.sender, amount);
    }

    function _transfer(address token, address to, uint256 amount) internal {
        TransferHelper.safeTransfer(token, to, amount);
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
        uint256 dsId = Initialize(core).lastDsId(id);
        (ct, ds) = __getCtDs(id, dsId);
    }

    function __getRaPair(Id id) internal view returns (address ra, address pa) {
        (ra, pa) = Initialize(core).underlyingAsset(id);
    }

    function __getCtDs(Id id, uint256 dsId) internal view returns (address ct, address ds) {
        (ct, ds) = Initialize(core).swapAsset(id, dsId);
    }

    function _swapNoTransfer(ICorkSwapAggregator.AggregatorParams memory params)
        internal
        returns (uint256 amount, address token)
    {
        if (params.enableAggregator) {
            _increaseAllowance(params.tokenIn, params.extRouter, params.amountIn);
            return (ICorkSwapAggregator(params.extRouter).swap(params, _msgSender()), params.tokenOut);
        } else {
            amount = params.amountIn;
            token = params.tokenIn;
        }
    }

    function _getDsId(Id id) internal view returns (uint256) {
        return Initialize(core).lastDsId(id);
    }

    function __findCtDsFromTokens(IWithdrawalRouter.Tokens[] calldata tokens, Id id)
        internal
        view
        returns (address ct, address ds, uint256 dsId)
    {
        uint256 length = tokens.length;
        for (uint256 i = 0; i < length; ++i) {
            try Asset(tokens[i].token).dsId() returns (uint256 _dsId) {
                dsId = _dsId;
                (ct, ds) = __getCtDs(id, dsId);

                return (ct, ds, dsId);

                // solhint-disable-next-line no-empty-blocks
            } catch {}
        }
        revert InvalidTokens();
    }

    function _handleLvRedeemDsExpired(Id id, address ct, address ds, uint256 dsId) internal {
        ERC20Burnable(ds).burn(_contractBalance(ds));

        _increaseAllowanceForProtocol(ct, _contractBalance(ct));

        _psm().redeemWithExpiredCt(id, dsId, _contractBalance(ct));
    }

    function _handleLvRedeem(IWithdrawalRouter.Tokens[] calldata tokens, bytes calldata params) internal {
        LvRedeemParams memory lvRedeemParams = abi.decode(params, (LvRedeemParams));

        (address ct, address ds, uint256 dsId) = __findCtDsFromTokens(tokens, lvRedeemParams.id);
        (address ra, address pa) = __getRaPair(lvRedeemParams.id);

        if (Asset(ct).isExpired()) {
            _handleLvRedeemDsExpired(lvRedeemParams.id, ct, ds, dsId);
        } else {
            _handleLvRedeemDsActive(lvRedeemParams.id, ct, ds, dsId, lvRedeemParams.dsMinOut, lvRedeemParams.receiver);
        }

        _swapNoTransfer(lvRedeemParams.paSwapAggregatorData);

        _transfer(ra, lvRedeemParams.receiver, _contractBalance(ra));
        _transfer(pa, lvRedeemParams.receiver, _contractBalance(pa));
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
            bool success = _handleSwap(ct, ra, true, diff, false);

            // will just transfer the ct to user if it fails to swap
            if (!success) {
                _transfer(ct, user, _contractBalance(ct));
            }
        } else {
            _increaseAllowance(ds, flashSwapRouter, diff);
            IDsFlashSwapCore flashswapRouter = _flashSwapRouter();

            // we essentially just give back the token to user if there's if for some reason
            // we fail to sell the DS
            // solhint-disable-next-line no-empty-blocks
            try flashswapRouter.swapDsforRa(id, dsId, diff, amountOutMin) returns (uint256) {}
            catch {
                _transfer(ds, user, _contractBalance(ct));
            }
        }
    }

    function _swap(AggregatorParams memory params, bool usePermit) internal returns (uint256 amount, address token) {
        if (usePermit) {
            _transferFromUserWithPermit(params.tokenIn, params.amountIn);
        } else {
            _transferFromUser(params.tokenIn, params.amountIn);
        }
        (amount, token) = _swapNoTransfer(params);
    }

    // handle ct/ra swap without intermediate token
    function _swap(Id id, bool raForCt, bool exactIn, uint256 amount)
        internal
        returns (uint256 amountOut, address output)
    {
        address input;
        {
            (address ra,) = __getRaPair(id);
            (address ct,) = __getCtDs(id);

            (input, output) = raForCt ? (ra, ct) : (ct, ra);
        }

        _handleSwap(input, output, exactIn, amount, true);

        amountOut = _contractBalance(output);
    }

    function _handleSwap(address input, address output, bool exactIn, uint256 amount, bool allowExplicitRevert)
        internal
        returns (bool success)
    {
        IPoolManager manager = IPoolManager(_hook().getPoolManager());
        PoolKey memory key = _hook().getPoolKey(input, output);

        // we want to swap arbitrary input to output token
        // so if input is less than output that means
        // input is token0 and output is token1 -> true
        // else means input is token1 and output is token0 -> false
        bool zeroForOne = input < output ? true : false;

        int256 swapAmount = exactIn ? -int256(amount) : int256(amount);

        IPoolManager.SwapParams memory swapParams =
            IPoolManager.SwapParams(zeroForOne, swapAmount, Constants.SQRT_PRICE_1_1);

        bytes memory raw = abi.encode(key, swapParams, input, output);

        // increase allowance for hook
        _increaseAllowance(input, hook, amount);

        if (allowExplicitRevert) {
            manager.unlock(raw);
            return true;
        }

        try manager.unlock(raw) {
            success = true;
        } catch {
            success = false;
        }
    }

    function _handleSwapCallback(bytes calldata raw) internal {
        address manager = _hook().getPoolManager();

        if (msg.sender != manager) {
            revert OnlyManager();
        }

        (PoolKey memory key, IPoolManager.SwapParams memory params, address _input, address _output) =
            abi.decode(raw, (PoolKey, IPoolManager.SwapParams, address, address));

        // no flash swaps
        BalanceDelta delta = IPoolManager(manager).swap(key, params, bytes(""));

        Currency input = Currency.wrap(_input);
        Currency output = Currency.wrap(_output);

        // order based on delta amount(i.e token0 and token1)
        (input, output) = input < output ? (input, output) : (output, input);

        int256 amount0 = int256(int128(BalanceDeltaLibrary.amount0(delta)));
        int256 amount1 = int256(int128(BalanceDeltaLibrary.amount1(delta)));

        uint256 settleAmount;
        uint256 takeAmount;

        // we pair the input and output token with the amount
        (input, settleAmount, output, takeAmount) = amount0 < 0
            ? (input, uint256(-amount0), output, uint256(amount1))
            : (output, uint256(-amount1), input, uint256(amount0));

        CurrencySettler.settle(input, IPoolManager(manager), address(this), settleAmount, false);
        CurrencySettler.take(output, IPoolManager(manager), address(this), takeAmount, false);
    }

    function unlockCallback(bytes calldata rawData) external returns (bytes memory) {
        _handleSwapCallback(rawData);
    }
}

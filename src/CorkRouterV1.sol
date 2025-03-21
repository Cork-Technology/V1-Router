// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {State} from "./State.sol";
import {AbstractAction} from "./AbstractAction.sol";
import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {IWithdrawalRouter} from "Depeg-swap/contracts/interfaces/IWithdrawalRouter.sol";
import {IDsFlashSwapCore} from "Depeg-swap/contracts/interfaces/IDsFlashSwapRouter.sol";
import {Initialize} from "Depeg-swap/contracts/interfaces/Init.sol";
import {ICorkRouterV1} from "./interfaces/ICorkRouterV1.sol";
import {IPermit2} from "permit2/interfaces/IPermit2.sol";

contract CorkRouterV1 is State, AbstractAction, ICorkRouterV1, IWithdrawalRouter {
    function depositPsm(AggregatorParams calldata params, Id id) external nonReentrant returns (uint256 received) {
        return _depositPsm(params, id, false);
    }

    function depositPsm(
        AggregatorParams calldata params,
        Id id,
        IPermit2.PermitSingle calldata permit,
        bytes calldata signature
    ) external nonReentrant returns (uint256 received) {
        // Process permit first to get token approval
        _permit2().permit(_msgSender(), permit, signature);

        return _depositPsm(params, id, true);
    }

    function _depositPsm(AggregatorParams calldata params, Id id, bool usePermit) internal returns (uint256 received) {
        _validateParams(params);

        address token;
        (received, token) = _swap(params, usePermit);

        _increaseAllowanceForProtocol(token, received);

        (received,) = _psm().depositPsm(id, received);

        _transferAllCtDsToUser(id);

        emit DepositPsm(_msgSender(), params.tokenIn, params.amountIn, id, received);
    }

    function depositLv(AggregatorParams calldata params, Id id, uint256 raTolerance, uint256 ctTolerance)
        external
        nonReentrant
        returns (uint256 received)
    {
        return _depositLv(params, id, raTolerance, ctTolerance, false);
    }

    function depositLv(
        AggregatorParams calldata params,
        Id id,
        uint256 raTolerance,
        uint256 ctTolerance,
        IPermit2.PermitSingle calldata permit,
        bytes calldata signature
    ) external nonReentrant returns (uint256 received) {
        _permit2().permit(_msgSender(), permit, signature);
        return _depositLv(params, id, raTolerance, ctTolerance, true);
    }

    function _depositLv(
        AggregatorParams calldata params,
        Id id,
        uint256 raTolerance,
        uint256 ctTolerance,
        bool usePermit
    ) internal returns (uint256 received) {
        _validateParams(params);

        address token;
        (received, token) = _swap(params, usePermit);

        _increaseAllowanceForProtocol(token, received);
        received = _vault().depositLv(id, received, raTolerance, ctTolerance);

        _transferAllLvToUser(id);

        emit DepositLv(_msgSender(), params.tokenIn, params.amountIn, id, received);
    }

    function route(address, IWithdrawalRouter.Tokens[] calldata tokens, bytes calldata routerData)
        external
        nonReentrant
    {
        _handleLvRedeem(tokens, routerData);
    }

    function repurchase(AggregatorParams calldata params, Id id, uint256 amount)
        external
        nonReentrant
        returns (RepurchaseReturn memory result)
    {
        return _repurchase(params, id, amount, false);
    }

    function repurchase(
        AggregatorParams calldata params,
        Id id,
        uint256 amount,
        IPermit2.PermitSingle calldata permit,
        bytes calldata signature
    ) external nonReentrant returns (RepurchaseReturn memory result) {
        _permit2().permit(_msgSender(), permit, signature);
        return _repurchase(params, id, amount, true);
    }

    function _repurchase(AggregatorParams calldata params, Id id, uint256 amount, bool usePermit)
        internal
        returns (RepurchaseReturn memory result)
    {
        _validateParams(params);

        address token;
        (amount, token) = _swap(params, usePermit);

        _increaseAllowanceForProtocol(token, amount);

        (result.dsId, result.receivedPa, result.receivedDs, result.feePercentage, result.fee, result.exchangeRates) =
            _psm().repurchase(id, amount);

        (, address ds) = __getCtDs(id);
        (, address pa) = __getRaPair(id);

        _transferToUser(ds, _contractBalance(ds));
        _transferToUser(pa, _contractBalance(pa));

        emit Repurchase(
            _msgSender(),
            params.tokenIn,
            params.amountIn,
            id,
            result.dsId,
            result.receivedPa,
            result.receivedDs,
            result.feePercentage,
            result.fee,
            result.exchangeRates
        );
    }

    function swapRaForDs(SwapRaForDsParams calldata params)
        external
        nonReentrant
        returns (IDsFlashSwapCore.SwapRaForDsReturn memory results)
    {
        _validateParamsCalldata(params.inputTokenAggregatorParams);

        (uint256 amount, address token) = _swap(params.inputTokenAggregatorParams, false);

        _increaseAllowanceForRouter(token, amount);
        results = _flashSwapRouter().swapRaforDs(
            params.id, params.dsId, amount, params.amountOutMin, params.approxParams, params.offchainGuess
        );

        (address ct, address ds) = __getCtDs(params.id);

        // we transfer both refunded ct and ds tokens
        _transferToUser(ct, _contractBalance(ct));
        _transferToUser(ds, _contractBalance(ds));

        _emitSwapEvent(
            SwapEventParams({
                sender: _msgSender(),
                swapType: SwapType.RaForDs,
                tokenIn: params.inputTokenAggregatorParams.tokenIn,
                amountIn: params.inputTokenAggregatorParams.amountIn,
                tokenOut: ds,
                amountOut: _contractBalance(ds),
                id: params.id,
                dsId: params.dsId,
                minOutput: params.amountOutMin,
                maxInput: 0,
                unused: 0,
                used: amount
            })
        );
    }

    function swapDsForRa(SwapDsForRaParams memory params) external nonReentrant returns (uint256 amountOut) {
        _validateParams(params.raAggregatorParams);

        (, address ds) = __getCtDs(params.id);

        _transferFromUser(ds, params.amount);

        _increaseAllowanceForRouter(ds, params.amount);
        amountOut = _flashSwapRouter().swapDsforRa(params.id, params.dsId, params.amount, params.raAmountOutMin);

        address token;

        // we change the amount in to accurately reflect the RA we got
        params.raAggregatorParams.amountIn = amountOut;
        (amountOut, token) = _swapNoTransfer(params.raAggregatorParams);

        _transferToUser(token, _contractBalance(token));

        _emitSwapEvent(
            SwapEventParams({
                sender: _msgSender(),
                swapType: SwapType.DsForRa,
                tokenIn: ds,
                amountIn: params.amount,
                tokenOut: token,
                amountOut: amountOut,
                id: params.id,
                dsId: params.dsId,
                minOutput: params.raAmountOutMin,
                maxInput: 0,
                unused: 0,
                used: params.amount
            })
        );
    }

    function swapRaForCtExactIn(AggregatorParams calldata params, Id id, uint256 amountOutMin)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        _validateParams(params);

        (uint256 amount,) = _swap(params, false);

        address ct;

        (amountOut, ct) = _swap(id, true, true, amount);

        uint256 dsId = _getDsId(id);

        if (amountOut < amountOutMin) revert Slippage();

        _transferToUser(ct, amountOut);

        _emitSwapEvent(
            SwapEventParams({
                sender: _msgSender(),
                swapType: SwapType.RaForCtExactIn,
                tokenIn: params.tokenIn,
                amountIn: params.amountIn,
                tokenOut: ct,
                amountOut: amountOut,
                id: id,
                dsId: dsId,
                minOutput: amountOutMin,
                maxInput: 0,
                unused: 0,
                used: amount
            })
        );
    }

    // we don't have an explicit slippage protection(max amount in) since the amount out we get from the aggregator swap(if any)s
    // automatically become the max input tokens. If it needs more than that the swap will naturally fails
    function swapRaForCtExactOut(AggregatorParams calldata params, Id id, uint256 amountOut)
        external
        nonReentrant
        returns (uint256 used, uint256 remaining)
    {
        _validateParams(params);

        // we expect ra to come out from this
        (uint256 initial, address ra) = _swap(params, false);

        address ct;
        (amountOut, ct) = _swap(id, true, false, amountOut);

        // transfer all ct
        _transferToUser(ct, amountOut);

        // take the diff and refund unused RA
        used = initial - _contractBalance(ra);
        remaining = _contractBalance(ra);

        assert(used + remaining == initial);

        // we use token out here since the token out is expected to be the target RA
        _transferToUser(ra, remaining);

        uint256 dsId = _getDsId(id);

        _emitSwapEvent(
            SwapEventParams({
                sender: _msgSender(),
                swapType: SwapType.RaForCtExactOut,
                tokenIn: params.tokenIn,
                amountIn: initial,
                tokenOut: ct,
                amountOut: amountOut,
                id: id,
                dsId: dsId,
                minOutput: 0,
                // since we allow all the RA
                maxInput: initial,
                unused: remaining,
                used: used
            })
        );
    }

    function swapCtForRaExactIn(AggregatorParams memory params, Id id, uint256 ctAmount, uint256 raAmountOutMin)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        _validateParams(params);

        (address ct,) = __getCtDs(id);
        _transferFromUser(ct, ctAmount);

        address ra;
        (amountOut, ra) = _swap(id, false, true, ctAmount);

        // we override the params
        // so that the aggregator contract get's the correct amount of funds
        // it's advised to use aggregator that supports exact in swap since this will be using that.
        // to set the minimum amount out for the RA -> target token swap,
        // consider doing it by :
        // 1. getting apreview of the CT -> RA trade
        // 2. do an offchain preview of RA -> target token with the amount from step 1
        // 3. use number from step 2 as the reference.
        params.amountIn = amountOut;

        if (amountOut < raAmountOutMin) revert Slippage();

        address tokenOut;
        (amountOut, tokenOut) = _swapNoTransfer(params);

        _transferToUser(tokenOut, amountOut);
        // transfer any unused ra
        _transferToUser(ra, _contractBalance(ra));

        uint256 dsId = _getDsId(id);

        _emitSwapEvent(
            SwapEventParams({
                sender: _msgSender(),
                swapType: SwapType.CtForRaExactIn,
                tokenIn: ct,
                amountIn: ctAmount,
                tokenOut: tokenOut,
                amountOut: amountOut,
                id: id,
                dsId: dsId,
                minOutput: raAmountOutMin,
                maxInput: 0,
                unused: 0,
                used: ctAmount
            })
        );
    }

    function swapCtForRaExactOut(AggregatorParams memory params, Id id, uint256 rAmountOut, uint256 amountInMax)
        external
        nonReentrant
        returns (uint256 ctUsed, uint256 ctRemaining, uint256 tokenOutAmountOut)
    {
        _validateParams(params);

        (address ct,) = __getCtDs(id);

        // we transfer the max amount first, and we will give back the unused ct later
        _transferFromUser(ct, amountInMax);
        uint256 initial = amountInMax;

        (uint256 amountOut,) = _swap(id, false, false, rAmountOut);

        // we override the params
        // so that the aggregator contract get's the correct amount of funds
        // it's advised to use aggregator that supports exact in swap since this will be using that.
        // to set the minimum amount out for the RA -> target token swap,
        // consider doing it by :
        // 1. getting apreview of the CT -> RA trade
        // 2. do an offchain preview of RA -> target token with the amount from step 1
        // 3. use number from step 2 as the reference.
        params.amountIn = amountOut;

        address tokenOut;
        (amountOut, tokenOut) = _swapNoTransfer(params);
        tokenOutAmountOut = amountOut;

        _transferToUser(tokenOut, amountOut);

        ctUsed = initial - _contractBalance(ct);
        assert(ctUsed + _contractBalance(ct) == initial);

        ctRemaining = _contractBalance(ct);
        // transfer any unused ct
        _transferToUser(ct, ctRemaining);

        uint256 dsId = _getDsId(id);

        _emitSwapEvent(
            SwapEventParams({
                sender: _msgSender(),
                swapType: SwapType.CtForRaExactOut,
                tokenIn: ct,
                amountIn: amountInMax,
                tokenOut: tokenOut,
                amountOut: tokenOutAmountOut,
                id: id,
                dsId: dsId,
                minOutput: 0,
                maxInput: amountInMax,
                unused: ctRemaining,
                used: ctUsed
            })
        );
    }

    function redeemRaWithDsPa(
        AggregatorParams calldata zapInParams,
        AggregatorParams memory zapOutParams,
        Id id,
        uint256 dsMaxIn
    ) external nonReentrant returns (uint256 dsUsed, uint256 outAmount) {
        _validateParamsCalldata(zapInParams);
        _validateParams(zapOutParams);

        (, address ds) = __getCtDs(id);

        (uint256 amount, address pa) = _swap(zapInParams, false);

        _transferFromUser(ds, dsMaxIn);

        _increaseAllowanceForProtocol(ds, dsMaxIn);
        _increaseAllowanceForProtocol(pa, amount);

        uint256 dsId = Initialize(core).lastDsId(id);

        (zapOutParams.amountIn,,, dsUsed) = _psm().redeemRaWithDsPa(id, dsId, amount);

        address outToken;
        (outAmount, outToken) = _swap(zapOutParams, false);

        _transferToUser(outToken, _contractBalance(outToken));

        // transfer unused DS
        _transferToUser(ds, _contractBalance(ds));

        emit RedeemRaWithDsPa(_msgSender(), pa, amount, ds, dsMaxIn, id, dsId, outToken, dsUsed, outAmount);
    }

    function _emitSwapEvent(SwapEventParams memory params) internal {
        emit Swap(
            params.sender,
            params.swapType,
            params.tokenIn,
            params.amountIn,
            params.tokenOut,
            params.amountOut,
            params.id,
            params.dsId,
            params.minOutput,
            params.maxInput,
            params.unused,
            params.used
        );
    }
}

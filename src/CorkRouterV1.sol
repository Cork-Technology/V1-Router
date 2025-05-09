// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {State} from "./State.sol";
import {AbstractAction} from "./AbstractAction.sol";
import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {IWithdrawalRouter} from "Depeg-swap/contracts/interfaces/IWithdrawalRouter.sol";
import {IDsFlashSwapCore} from "Depeg-swap/contracts/interfaces/IDsFlashSwapRouter.sol";
import {Initialize} from "Depeg-swap/contracts/interfaces/Init.sol";
import {ICorkRouterV1} from "./interfaces/ICorkRouterV1.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";

/**
 * @title Cork Router V1
 * @notice A router contract that enables users to interact with the Cork Protocol, providing various swapping and deposit functionalities
 * @dev This contract handles deposits, swaps, and redemptions between different token types in the Cork ecosystem
 * @author Cork Protocol team
 */
contract CorkRouterV1 is State, AbstractAction, ICorkRouterV1, IWithdrawalRouter {
    /// @inheritdoc ICorkRouterV1
    function depositPsm(AggregatorParams calldata params, Id id) external nonReentrant returns (uint256 received) {
        return _depositPsm(params, id, false);
    }

    /// @inheritdoc ICorkRouterV1
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

    /// @inheritdoc ICorkRouterV1
    function depositLv(
        AggregatorParams calldata params,
        Id id,
        uint256 raTolerance,
        uint256 ctTolerance,
        uint256 deadline,
        uint256 minimumLvOut
    ) external nonReentrant returns (uint256 received) {
        return _depositLv(params, id, raTolerance, ctTolerance, false, deadline, minimumLvOut);
    }

    /// @inheritdoc ICorkRouterV1
    function depositLv(
        AggregatorParams calldata params,
        Id id,
        uint256 raTolerance,
        uint256 ctTolerance,
        IPermit2.PermitSingle calldata permit,
        bytes calldata signature,
        uint256 deadline,
        uint256 minimumLvOut
    ) external nonReentrant returns (uint256 received) {
        _permit2().permit(_msgSender(), permit, signature);
        return _depositLv(params, id, raTolerance, ctTolerance, true, deadline, minimumLvOut);
    }

    function _depositLv(
        AggregatorParams calldata params,
        Id id,
        uint256 raTolerance,
        uint256 ctTolerance,
        bool usePermit,
        uint256 deadline,
        uint256 minimumLvOut
    ) internal returns (uint256 received) {
        _validateParams(params);

        address token;
        (received, token) = _swap(params, usePermit);

        _increaseAllowanceForProtocol(token, received);
        received = _vault().depositLv(id, received, raTolerance, ctTolerance, minimumLvOut, deadline);

        _transferAllLvToUser(id);

        (address ra,) = __getRaPair(id);
        (address ct,) = __getCtDs(id);

        _transferToUser(ra, _contractBalance(ra));
        _transferToUser(ct, _contractBalance(ct));

        emit DepositLv(_msgSender(), params.tokenIn, params.amountIn, id, received);
    }

    function route(address, IWithdrawalRouter.Tokens[] calldata tokens, bytes calldata routerData)
        external
        nonReentrant
    {
        _handleLvRedeem(tokens, routerData);
    }

    /// @inheritdoc ICorkRouterV1
    function repurchase(AggregatorParams calldata params, Id id, uint256 amount)
        external
        nonReentrant
        returns (RepurchaseReturn memory result)
    {
        return _repurchase(params, id, amount, false);
    }

    /// @inheritdoc ICorkRouterV1
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

    /// @inheritdoc ICorkRouterV1
    function swapRaForDs(SwapRaForDsParams calldata params)
        external
        nonReentrant
        returns (IDsFlashSwapCore.SwapRaForDsReturn memory results)
    {
        return _swapRaForDs(params, false);
    }

    /// @inheritdoc ICorkRouterV1
    function swapRaForDs(
        SwapRaForDsParams calldata params,
        IPermit2.PermitSingle calldata permit,
        bytes calldata signature
    ) external nonReentrant returns (IDsFlashSwapCore.SwapRaForDsReturn memory results) {
        _permit2().permit(_msgSender(), permit, signature);
        return _swapRaForDs(params, true);
    }

    function _swapRaForDs(SwapRaForDsParams calldata params, bool usePermit)
        internal
        returns (IDsFlashSwapCore.SwapRaForDsReturn memory results)
    {
        {
            uint256 currentDsId = _getDsId(params.id);

            if (currentDsId > params.dsId) revert Expired();
        }

        _validateParamsCalldata(params.inputTokenAggregatorParams);

        (uint256 amount, address token) = _swap(params.inputTokenAggregatorParams, usePermit);

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

    /// @inheritdoc ICorkRouterV1
    function swapDsForRa(SwapDsForRaParams memory params) external nonReentrant returns (uint256 amountOut) {
        return _swapDsForRa(params, false);
    }

    /// @inheritdoc ICorkRouterV1
    function swapDsForRa(
        SwapDsForRaParams memory params,
        IPermit2.PermitSingle calldata permit,
        bytes calldata signature
    ) external nonReentrant returns (uint256 amountOut) {
        _permit2().permit(_msgSender(), permit, signature);
        return _swapDsForRa(params, true);
    }

    function _swapDsForRa(SwapDsForRaParams memory params, bool usePermit) internal returns (uint256 amountOut) {
        {
            uint256 currentDsId = _getDsId(params.id);

            if (currentDsId > params.dsId) revert Expired();
        }

        _validateParams(params.raAggregatorParams);

        (, address ds) = __getCtDs(params.id);

        if (usePermit) {
            _transferFromUserWithPermit(ds, params.amount);
        } else {
            _transferFromUser(ds, params.amount);
        }

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

    /// @inheritdoc ICorkRouterV1
    function swapRaForCtExactIn(AggregatorParams calldata params, Id id, uint256 amountOutMin)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        return _swapRaForCtExactIn(params, id, amountOutMin, false);
    }

    /// @inheritdoc ICorkRouterV1
    function swapRaForCtExactIn(
        AggregatorParams calldata params,
        Id id,
        uint256 amountOutMin,
        IPermit2.PermitSingle calldata permit,
        bytes calldata signature
    ) external nonReentrant returns (uint256 amountOut) {
        _permit2().permit(_msgSender(), permit, signature);
        return _swapRaForCtExactIn(params, id, amountOutMin, true);
    }

    function _swapRaForCtExactIn(AggregatorParams calldata params, Id id, uint256 amountOutMin, bool usePermit)
        internal
        returns (uint256 amountOut)
    {
        _validateParams(params);

        (uint256 amount,) = _swap(params, usePermit);

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
    /// @inheritdoc ICorkRouterV1
    function swapRaForCtExactOut(AggregatorParams calldata params, Id id, uint256 amountOut)
        external
        nonReentrant
        returns (uint256 used, uint256 remaining)
    {
        return _swapRaForCtExactOut(params, id, amountOut, false);
    }

    /// @inheritdoc ICorkRouterV1
    function swapRaForCtExactOut(
        AggregatorParams calldata params,
        Id id,
        uint256 amountOut,
        IPermit2.PermitSingle calldata permit,
        bytes calldata signature
    ) external nonReentrant returns (uint256 used, uint256 remaining) {
        _permit2().permit(_msgSender(), permit, signature);
        return _swapRaForCtExactOut(params, id, amountOut, true);
    }

    function _swapRaForCtExactOut(AggregatorParams calldata params, Id id, uint256 amountOut, bool usePermit)
        internal
        returns (uint256 used, uint256 remaining)
    {
        _validateParams(params);

        // we expect ra to come out from this
        (uint256 initial, address ra) = _swap(params, usePermit);

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

    /// @inheritdoc ICorkRouterV1
    function swapCtForRaExactIn(AggregatorParams memory params, Id id, uint256 ctAmount, uint256 raAmountOutMin)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        return _swapCtForRaExactIn(params, id, ctAmount, raAmountOutMin, false);
    }

    /// @inheritdoc ICorkRouterV1
    function swapCtForRaExactIn(
        AggregatorParams memory params,
        Id id,
        uint256 ctAmount,
        uint256 raAmountOutMin,
        IPermit2.PermitSingle calldata permit,
        bytes calldata signature
    ) external nonReentrant returns (uint256 amountOut) {
        _permit2().permit(_msgSender(), permit, signature);
        return _swapCtForRaExactIn(params, id, ctAmount, raAmountOutMin, true);
    }

    function _swapCtForRaExactIn(
        AggregatorParams memory params,
        Id id,
        uint256 ctAmount,
        uint256 raAmountOutMin,
        bool usePermit
    ) internal returns (uint256 amountOut) {
        _validateParams(params);

        (address ct,) = __getCtDs(id);
        if (usePermit) {
            _transferFromUserWithPermit(ct, ctAmount);
        } else {
            _transferFromUser(ct, ctAmount);
        }

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

    /// @inheritdoc ICorkRouterV1
    function swapCtForRaExactOut(AggregatorParams memory params, Id id, uint256 rAmountOut, uint256 amountInMax)
        external
        nonReentrant
        returns (uint256 ctUsed, uint256 ctRemaining, uint256 tokenOutAmountOut)
    {
        return _swapCtForRaExactOut(params, id, rAmountOut, amountInMax, false);
    }

    /// @inheritdoc ICorkRouterV1
    function swapCtForRaExactOut(
        AggregatorParams memory params,
        Id id,
        uint256 rAmountOut,
        uint256 amountInMax,
        IPermit2.PermitSingle calldata permit,
        bytes calldata signature
    ) external nonReentrant returns (uint256 ctUsed, uint256 ctRemaining, uint256 tokenOutAmountOut) {
        _permit2().permit(_msgSender(), permit, signature);
        return _swapCtForRaExactOut(params, id, rAmountOut, amountInMax, true);
    }

    function _swapCtForRaExactOut(
        AggregatorParams memory params,
        Id id,
        uint256 rAmountOut,
        uint256 amountInMax,
        bool usePermit
    ) internal returns (uint256 ctUsed, uint256 ctRemaining, uint256 tokenOutAmountOut) {
        _validateParams(params);

        (address ct,) = __getCtDs(id);

        // we transfer the max amount first, and we will give back the unused ct later
        if (usePermit) {
            _transferFromUserWithPermit(ct, amountInMax);
        } else {
            _transferFromUser(ct, amountInMax);
        }
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

    /// @inheritdoc ICorkRouterV1
    function redeemRaWithDsPa(
        AggregatorParams calldata zapInParams,
        AggregatorParams memory zapOutParams,
        Id id,
        uint256 dsMaxIn
    ) external nonReentrant returns (uint256 dsUsed, uint256 outAmount) {
        return _redeemRaWithDsPa(zapInParams, zapOutParams, id, dsMaxIn, false);
    }

    /// @inheritdoc ICorkRouterV1
    function redeemRaWithDsPa(
        AggregatorParams calldata zapInParams,
        AggregatorParams memory zapOutParams,
        Id id,
        uint256 dsMaxIn,
        IPermit2.PermitBatch calldata permit,
        bytes calldata signature
    ) external nonReentrant returns (uint256 dsUsed, uint256 outAmount) {
        _permit2().permit(_msgSender(), permit, signature);
        return _redeemRaWithDsPa(zapInParams, zapOutParams, id, dsMaxIn, true);
    }

    function _redeemRaWithDsPa(
        AggregatorParams calldata zapInParams,
        AggregatorParams memory zapOutParams,
        Id id,
        uint256 dsMaxIn,
        bool usePermit
    ) internal returns (uint256 dsUsed, uint256 outAmount) {
        _validateParamsCalldata(zapInParams);
        _validateParams(zapOutParams);

        (, address ds) = __getCtDs(id);

        (uint256 amount, address pa) = _swap(zapInParams, usePermit);

        if (usePermit) {
            _transferFromUserWithPermit(ds, dsMaxIn);
        } else {
            _transferFromUser(ds, dsMaxIn);
        }

        _increaseAllowanceForProtocol(ds, dsMaxIn);
        _increaseAllowanceForProtocol(pa, amount);

        uint256 dsId = Initialize(core).lastDsId(id);

        (zapOutParams.amountIn,,, dsUsed) = _psm().redeemRaWithDsPa(id, dsId, amount);

        address outToken;
        (outAmount, outToken) = _swapNoTransfer(zapOutParams);

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

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {State} from "./State.sol";
import {AbstractAction} from "./AbstractAction.sol";
import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {IWithdrawalRouter} from "Depeg-swap/contracts/interfaces/IWithdrawalRouter.sol";
import {IDsFlashSwapCore} from "Depeg-swap/contracts/interfaces/IDsFlashSwapRouter.sol";
import {Initialize} from "Depeg-swap/contracts/interfaces/Init.sol";
import {ICorkRouterV1} from "./interfaces/ICorkRouterV1.sol";

// TODO  check events input and output params
// TODO  resolve stack errors
contract CorkRouterV1 is State, AbstractAction, ICorkRouterV1, IWithdrawalRouter {
    function depositPsm(AggregatorParams calldata params, Id id) external returns (uint256 received) {
        address token;
        (received, token) = _swap(params);

        _increaseAllowanceForProtocol(token, received);

        (received,) = _psm().depositPsm(id, received);

        _transferAllCtDsToUser(id);

        emit DepositPsm(_msgSender(), token, params.amountIn, id, received);
    }

    function depositLv(AggregatorParams calldata params, Id id, uint256 raTolerance, uint256 ctTolerance)
        external
        returns (uint256 received)
    {
        address token;
        (received, token) = _swap(params);

        _increaseAllowanceForProtocol(token, received);
        received = _vault().depositLv(id, received, raTolerance, ctTolerance);

        _transferAllLvToUser(id);

        emit DepositLv(_msgSender(), token, params.amountIn, id, raTolerance, ctTolerance, received);
    }

    function route(address, IWithdrawalRouter.Tokens[] calldata tokens, bytes calldata routerData) external {
        _handleLvRedeem(tokens, routerData);
    }

    function repurchase(AggregatorParams calldata params, Id id, uint256 amount)
        external
        returns (
            uint256 dsId,
            uint256 receivedPa,
            uint256 receivedDs,
            uint256 feePercentage,
            uint256 fee,
            uint256 exchangeRates
        )
    {
        address token;
        (amount, token) = _swap(params);

        _increaseAllowanceForProtocol(token, amount);

        (dsId, receivedPa, receivedDs, feePercentage, fee, exchangeRates) = _psm().repurchase(id, amount);

        (, address ds) = __getCtDs(id);
        (, address pa) = __getRaPair(id);

        _transferToUser(ds, _contractBalance(ds));
        _transferToUser(pa, _contractBalance(pa));

        emit Repurchase(
            _msgSender(), token, params.amountIn, id, dsId, receivedPa, receivedDs, feePercentage, fee, exchangeRates
        );
    }

    function swapRaForDs(SwapRaForDsParams calldata params)
        external
        returns (IDsFlashSwapCore.SwapRaForDsReturn memory results)
    {
        (uint256 amount, address token) = _swap(params.inputTokenAggregatorParams);

        _increaseAllowanceForRouter(token, amount);
        results = _flashSwapRouter().swapRaforDs(
            params.id, params.dsId, amount, params.amountOutMin, params.approxParams, params.offchainGuess
        );

        (address ct, address ds) = __getCtDs(params.id);

        // we transfer both refunded ct and ds tokens
        _transferToUser(ct, _contractBalance(ct));
        _transferToUser(ds, _contractBalance(ds));

        emit Swap(
            _msgSender(),
            SwapType.RaForDs,
            token,
            params.inputTokenAggregatorParams.amountIn,
            ds,
            _contractBalance(ds),
            params.id,
            params.dsId,
            params.amountOutMin,
            0, // maxInput
            0, // unused
            amount // used
        );
    }

    function swapDsForRa(SwapDsForRaParams memory params) external returns (uint256 amountOut) {
        (, address ds) = __getCtDs(params.id);

        _transferFromUser(ds, params.amount);

        _increaseAllowanceForRouter(ds, params.amount);
        amountOut = _flashSwapRouter().swapDsforRa(params.id, params.dsId, params.amount, params.raAmountOutMin);

        address token;

        // we change the amount in to accurately reflect the RA we got
        params.raAggregatorParams.amountIn = amountOut;
        (amountOut, token) = _swapNoTransfer(params.raAggregatorParams);

        _transferToUser(token, _contractBalance(token));

        emit Swap(
            _msgSender(),
            SwapType.DsForRa,
            ds,
            params.amount,
            token,
            amountOut,
            params.id,
            params.dsId,
            params.raAmountOutMin,
            0, // maxInput
            0, // unused
            params.amount // used
        );
    }

    function swapRaForCtExactIn(AggregatorParams calldata params, Id id, uint256 amountOutMin)
        external
        returns (uint256 amountOut)
    {
        (uint256 amount,) = _swap(params);

        address ct;

        (amountOut, ct) = _swap(id, true, true, amount);

        if (amountOut < amountOutMin) revert Slippage();

        _transferToUser(ct, amountOut);

        emit Swap(
            _msgSender(),
            SwapType.RaForCtExactIn,
            params.tokenIn,
            params.amountIn,
            ct,
            amountOut,
            id,
            0, // dsId
            amountOutMin,
            0, // maxInput
            0, // unused
            amount // used
        );
    }

    // we don't have an explicit slippage protection(max amount in) since the amount out we get from the aggregator swap(if any)s
    // automatically become the max input tokens. If it needs more than that the swap will naturally fails
    function swapRaForCtExactOut(AggregatorParams calldata params, Id id, uint256 amountOut)
        external
        returns (uint256 used, uint256 remaining)
    {
        // we expect ra to come out from this
        (uint256 initial, address ra) = _swap(params);

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

        emit Swap(
            _msgSender(),
            SwapType.RaForCtExactOut,
            ra,
            initial,
            ct,
            amountOut,
            id,
            0, // dsId
            0, // minOutput
            0, // maxInput
            remaining, // unused
            used // used
        );
    }

    function swapCtForRaExactIn(AggregatorParams memory params, Id id, uint256 ctAmount, uint256 raAmountOutMin)
        external
        returns (uint256 amountOut)
    {
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

        emit Swap(
            _msgSender(),
            SwapType.CtForRaExactIn,
            ct,
            ctAmount,
            tokenOut,
            amountOut,
            id,
            0, // dsId
            raAmountOutMin,
            0, // maxInput
            _contractBalance(ra), // unused
            ctAmount // used
        );
    }

    function swapCtForRaExactOut(AggregatorParams memory params, Id id, uint256 rAmountOut, uint256 amountInMax)
        external
        returns (uint256 ctUsed, uint256 ctRemaining, uint256 tokenOutAmountOut)
    {
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

        emit Swap(
            _msgSender(),
            SwapType.CtForRaExactOut,
            ct,
            amountInMax,
            tokenOut,
            tokenOutAmountOut,
            id,
            0, // dsId
            0, // minOutput
            amountInMax, // maxInput
            ctRemaining, // unused
            ctUsed // used
        );
    }

    function redeemRaWithDsPa(
        AggregatorParams calldata zapInParams,
        AggregatorParams memory zapOutParams,
        Id id,
        uint256 dsMaxIn
    ) external returns (uint256 dsUsed, uint256 outAmount) {
        (, address ds) = __getCtDs(id);

        (uint256 amount, address pa) = _swap(zapInParams);

        _transferFromUser(ds, dsMaxIn);

        _increaseAllowanceForProtocol(ds, dsMaxIn);
        _increaseAllowanceForProtocol(pa, amount);

        uint256 dsId = Initialize(core).lastDsId(id);

        (zapOutParams.amountIn,,, dsUsed) = _psm().redeemRaWithDsPa(id, dsId, amount);

        address outToken;
        (outAmount, outToken) = _swap(zapOutParams);

        _transferToUser(outToken, _contractBalance(outToken));

        // transfer unused DS
        _transferToUser(ds, _contractBalance(ds));

        emit RedeemRaWithDsPa(_msgSender(), pa, amount, ds, dsMaxIn, id, outToken, dsUsed, outAmount);
    }
}

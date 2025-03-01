// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {State} from "./State.sol";
import {AbtractAction} from "./AbstractAction.sol";
import {ICorkSwapAggregator} from "./interfaces/ICorkSwapAggregator.sol";
import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {IWithdrawalRouter} from "Depeg-swap/contracts/interfaces/IWithdrawalRouter.sol";
import {IDsFlashSwapCore} from "Depeg-swap/contracts/interfaces/IDsFlashSwapRouter.sol";

contract CorkRouterV1 is State, AbtractAction, IWithdrawalRouter {
    constructor(address __core, address __flashSwapRouter, address __hook) State(__core, __flashSwapRouter, __hook) {}

    function depositPsm(ICorkSwapAggregator.SwapParams calldata params, Id id) external returns (uint256 received) {
        address token;
        (received, token) = _swap(params);

        _increaseAllowanceForProtocol(token, received);

        (received,) = _psm().depositPsm(id, received);

        _transferAllCtDsToUser(id);
    }

    function depositLv(ICorkSwapAggregator.SwapParams calldata params, Id id, uint256 raTolerance, uint256 ctTolerance)
        external
        returns (uint256 received)
    {
        address token;
        (received, token) = _swap(params);

        _increaseAllowanceForProtocol(token, received);
        received = _vault().depositLv(id, received, raTolerance, ctTolerance);

        _transferAllLvToUser(id);
    }

    function route(address, IWithdrawalRouter.Tokens[] calldata tokens, bytes calldata routerData) external {
        _handleLvRedeem(tokens, routerData);
    }

    function repurchase(ICorkSwapAggregator.SwapParams calldata params, Id id, uint256 amount)
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
    }

    function swapRaForDs(ICorkSwapAggregator.SwapRaForDsParams calldata params)
        external
        returns (IDsFlashSwapCore.SwapRaForDsReturn memory results)
    {
        (uint256 amount, address token) = _swap(params.inputTokenSwapParams);

        _increaseAllowanceForRouter(token, amount);
        results = _flashSwapRouter().swapRaforDs(
            params.id, params.dsId, amount, params.amountOutMin, params.approxParams, params.offchainGuess
        );

        (address ct, address ds) = __getCtDs(params.id);

        // we transfer both refunded ct and ds tokens
        _transferToUser(ct, _contractBalance(ct));
        _transferToUser(ds, _contractBalance(ds));
    }

    function swapDsForRa(ICorkSwapAggregator.SwapDsForRaParams memory params) external returns (uint256 amountOut) {
        (, address ds) = __getCtDs(params.id);

        _transferFromUser(ds, params.amount);

        _increaseAllowanceForRouter(ds, params.amount);
        amountOut = _flashSwapRouter().swapDsforRa(params.id, params.dsId, params.amount, params.raAmountOutMin);

        address token;

        // we change the amount in to accurately reflect the RA we got
        params.raSwapParams.amountIn = amountOut;
        (amountOut, token) = _swapNoTransfer(params.raSwapParams);

        _transferToUser(token, _contractBalance(token));
    }
}

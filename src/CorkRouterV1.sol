// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {State} from "./State.sol";
import {AbtractAction} from "./AbstractAction.sol";
import {ICorkSwapAggregator} from "./interfaces/ICorkSwapAggregator.sol";
import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {IWithdrawalRouter} from "Depeg-swap/contracts/interfaces/IWithdrawalRouter.sol";

contract CorkRouterV1 is State, AbtractAction, IWithdrawalRouter {
    constructor(address __core, address __flashSwapRouter, address __hook) State(__core, __flashSwapRouter, __hook) {}

    function depositPsm(ICorkSwapAggregator.SwapParams calldata params, Id id) external returns (uint256 received) {
        uint256 zapAmount = _swap(params);

        _increaseAllowanceForProtocol(params.tokenOut, zapAmount);

        (received,) = _psm().depositPsm(id, zapAmount);

        _transferAllCtDsToUser(id);
    }

    function depositLv(ICorkSwapAggregator.SwapParams calldata params, Id id, uint256 raTolerance, uint256 ctTolerance)
        external
        returns (uint256 received)
    {
        uint256 amount = _swap(params);

        _increaseAllowanceForProtocol(params.tokenOut, amount);
        received = _vault().depositLv(id, amount, raTolerance, ctTolerance);

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
        amount = _swap(params);

        _increaseAllowanceForProtocol(params.tokenOut, amount);

        (dsId, receivedPa, receivedDs, feePercentage, fee, exchangeRates) = _psm().repurchase(id, amount);

        (, address ds) = __getCtDs(id);
        (, address pa) = __getRaPair(id);

        _transferToUser(ds, _contractBalance(ds));
        _transferToUser(pa, _contractBalance(pa));
    }
}

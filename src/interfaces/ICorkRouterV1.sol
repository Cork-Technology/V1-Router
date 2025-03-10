// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {ICommon} from "./ICommon.sol";
import {IWithdrawalRouter} from "Depeg-swap/contracts/interfaces/IWithdrawalRouter.sol";
import {IDsFlashSwapCore} from "Depeg-swap/contracts/interfaces/IDsFlashSwapRouter.sol";

// TODO  check events input and output params
interface ICorkRouterV1 is ICommon {
    function depositPsm(AggregatorParams calldata params, Id id) external returns (uint256 received);

    // Event for depositPsm function
    event DepositPsm(address indexed caller, address inputToken, uint256 inputAmount, Id id, uint256 received);

    function depositLv(AggregatorParams calldata params, Id id, uint256 raTolerance, uint256 ctTolerance)
        external
        returns (uint256 received);

    // Event for depositLv function
    event DepositLv(
        address indexed caller,
        address inputToken,
        uint256 inputAmount,
        Id id,
        uint256 raTolerance,
        uint256 ctTolerance,
        uint256 received
    );

    function repurchase(AggregatorParams calldata params, Id id, uint256 amount)
        external
        returns (
            uint256 dsId,
            uint256 receivedPa,
            uint256 receivedDs,
            uint256 feePercentage,
            uint256 fee,
            uint256 exchangeRates
        );

    // Event for repurchase function
    event Repurchase(
        address indexed caller,
        address inputToken,
        uint256 inputAmount,
        Id id,
        uint256 dsId,
        uint256 receivedPa,
        uint256 receivedDs,
        uint256 feePercentage,
        uint256 fee,
        uint256 exchangeRates
    );

    // Enum for swap types
    enum SwapType {
        RaForDs,
        DsForRa,
        RaForCtExactIn,
        RaForCtExactOut,
        CtForRaExactIn,
        CtForRaExactOut
    }

    // Unified Swap event for all swap functions
    event Swap(
        address indexed caller,
        SwapType swapType,
        address inputToken,
        uint256 inputAmount,
        address outputToken,
        uint256 outputAmount,
        Id id,
        uint256 dsId,
        uint256 minOutput,
        uint256 maxInput,
        uint256 unused,
        uint256 used
    );

    function swapRaForDs(SwapRaForDsParams calldata params)
        external
        returns (IDsFlashSwapCore.SwapRaForDsReturn memory results);

    function swapDsForRa(SwapDsForRaParams memory params) external returns (uint256 amountOut);

    function swapRaForCtExactIn(AggregatorParams calldata params, Id id, uint256 amountOutMin)
        external
        returns (uint256 amountOut);

    function swapRaForCtExactOut(AggregatorParams calldata params, Id id, uint256 amountOut)
        external
        returns (uint256 used, uint256 remaining);

    function swapCtForRaExactIn(AggregatorParams memory params, Id id, uint256 ctAmount, uint256 raAmountOutMin)
        external
        returns (uint256 amountOut);

    function swapCtForRaExactOut(AggregatorParams memory params, Id id, uint256 rAmountOut, uint256 amountInMax)
        external
        returns (uint256 ctUsed, uint256 ctRemaining, uint256 tokenOutAmountOut);

    function redeemRaWithDsPa(
        AggregatorParams calldata zapInParams,
        AggregatorParams memory zapOutParams,
        Id id,
        uint256 dsMaxIn
    ) external returns (uint256 dsUsed, uint256 outAmount);

    // Event for redeemRaWithDsPa function
    event RedeemRaWithDsPa(
        address indexed caller,
        address paToken,
        uint256 paAmount,
        address dsToken,
        uint256 dsMaxIn,
        Id id,
        address outputToken,
        uint256 dsUsed,
        uint256 outAmount
    );
}

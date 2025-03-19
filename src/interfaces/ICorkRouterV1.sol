// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {ICommon} from "./ICommon.sol";
import {IWithdrawalRouter} from "Depeg-swap/contracts/interfaces/IWithdrawalRouter.sol";
import {IDsFlashSwapCore} from "Depeg-swap/contracts/interfaces/IDsFlashSwapRouter.sol";

interface ICorkRouterV1 is ICommon {
    struct SwapEventParams {
        address sender;
        SwapType swapType;
        address tokenIn;
        uint256 amountIn;
        address tokenOut;
        uint256 amountOut;
        Id id;
        uint256 dsId;
        uint256 minOutput;
        uint256 maxInput;
        uint256 unused;
        uint256 used;
    }

    // Enum for swap types
    enum SwapType {
        RaForDs,
        DsForRa,
        RaForCtExactIn,
        RaForCtExactOut,
        CtForRaExactIn,
        CtForRaExactOut
    }

    // Event for depositPsm function
    event DepositPsm(
        address indexed caller, address inputToken, uint256 inputAmount, Id indexed id, uint256 ctDsReceived
    );

    // Event for depositLv function
    event DepositLv(address indexed caller, address inputToken, uint256 inputAmount, Id indexed id, uint256 lvReceived);

    // Event for repurchase function
    event Repurchase(
        address indexed caller,
        address inputToken,
        uint256 inputAmount,
        Id indexed id,
        uint256 indexed dsId,
        uint256 receivedPa,
        uint256 receivedDs,
        uint256 feePercentage,
        uint256 fee,
        uint256 exchangeRates
    );

    // Unified Swap event for all swap functions
    event Swap(
        address indexed caller,
        SwapType indexed swapType,
        address inputToken,
        uint256 inputAmount,
        address outputToken,
        uint256 outputAmount,
        Id indexed id,
        uint256 dsId,
        uint256 minOutput,
        uint256 maxInput,
        uint256 unused,
        uint256 used
    );

    // Event for redeemRaWithDsPa function
    event RedeemRaWithDsPa(
        address indexed caller,
        address paToken,
        uint256 paAmount,
        address dsToken,
        uint256 dsMaxIn,
        Id indexed id,
        uint256 indexed dsId,
        address outputToken,
        uint256 dsUsed,
        uint256 outAmount
    );

    function depositPsm(AggregatorParams calldata params, Id id) external returns (uint256 received);

    function depositLv(AggregatorParams calldata params, Id id, uint256 raTolerance, uint256 ctTolerance)
        external
        returns (uint256 received);

    function repurchase(AggregatorParams calldata params, Id id, uint256 amount)
        external
        returns (RepurchaseReturn memory result);

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
}

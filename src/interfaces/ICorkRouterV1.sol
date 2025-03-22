// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {ICommon} from "./ICommon.sol";
import {IDsFlashSwapCore} from "Depeg-swap/contracts/interfaces/IDsFlashSwapRouter.sol";
import {IPermit2} from "permit2/interfaces/IPermit2.sol";

/**
 * @title ICorkRouterV1
 * @dev Interface for the Cork Router V1 which handles token swaps, deposits, and redemptions
 *      between Redemption Assets (RA), Cover Tokens (CT), Pegged Assets (PA), and Depeg-Swap (DS) tokens.
 *      Extends ICommon interface for shared functionality.
 * @author Cork Protocol
 */
interface ICorkRouterV1 is ICommon {
    /**
     * @dev Parameters for swap events containing detailed information about the swap
     * @param sender The address that initiated the swap
     * @param tokenIn The address of the token being swapped in (initially provided by user)
     * @param tokenOut The address of the token being received (final token sent to user)
     * @param swapType The type of swap being performed (from SwapType enum)
     * @param id The Market identifier for the ModuleCore contract
     * @param amountIn The amount of input tokens provided by user
     * @param amountOut The amount of output tokens received by user
     * @param dsId The DS-ID from ModuleCore contract if applicable
     * @param minOutput The minimum amount of output tokens to receive (slippage protection)
     * @param maxInput The maximum amount of input tokens to spend (slippage protection)
     * @param unused Placeholder for unused amounts in certain swap types
     * @param used Amount of tokens actually used in the swap
     */
    struct SwapEventParams {
        address sender;
        address tokenIn;
        address tokenOut;
        SwapType swapType;
        Id id;
        uint256 amountIn;
        uint256 amountOut;
        uint256 dsId;
        uint256 minOutput;
        uint256 maxInput;
        uint256 unused;
        uint256 used;
    }

    /**
     * @dev Enum of different swap types supported by the router
     * @param RaForDs Swap Redemption Asset (RA) for Depeg-Swap token (DS)
     * @param DsForRa Swap Depeg-Swap token (DS) for Redemption Asset (RA)
     * @param RaForCtExactIn Swap exact amount of Redemption Asset (RA) for Cover Token (CT)
     * @param RaForCtExactOut Swap Redemption Asset (RA) for exact amount of Cover Token (CT)
     * @param CtForRaExactIn Swap exact amount of Cover Token (CT) for Redemption Asset (RA)
     * @param CtForRaExactOut Swap Cover Token (CT) for exact amount of Redemption Asset (RA)
     */
    enum SwapType {
        RaForDs,
        DsForRa,
        RaForCtExactIn,
        RaForCtExactOut,
        CtForRaExactIn,
        CtForRaExactOut
    }

    /**
     * @dev Emitted when tokens are deposited into the PSM (Peg Stability Module)
     * @param caller The address that called the deposit function
     * @param inputToken The token address that was deposited (original token provided by user)
     * @param inputAmount The amount of tokens deposited (original amount provided by user)
     * @param id The Market identifier for the ModuleCore contract
     * @param ctDsReceived The amount of CT/DS tokens received from the deposit
     */
    event DepositPsm(
        address indexed caller, address inputToken, uint256 inputAmount, Id indexed id, uint256 ctDsReceived
    );

    /**
     * @dev Emitted when tokens are deposited into the LV (Liquidity Vault)
     * @param caller The address that called the deposit function
     * @param inputToken The token address that was deposited (original token provided by user)
     * @param inputAmount The amount of tokens deposited (original amount provided by user)
     * @param id The Market identifier for the ModuleCore contract
     * @param lvReceived The amount of LV tokens received from the deposit
     */
    event DepositLv(address indexed caller, address inputToken, uint256 inputAmount, Id indexed id, uint256 lvReceived);

    /**
     * @dev Emitted when a repurchase operation is executed
     * @param caller The address that called the repurchase function
     * @param inputToken The token address that was used for repurchase (original token provided by user)
     * @param inputAmount The amount of tokens used for repurchase (original amount provided by user)
     * @param id The Market identifier for the ModuleCore contract
     * @param dsId The DS-ID from ModuleCore contract used in the repurchase
     * @param receivedPa The amount of PA tokens received
     * @param receivedDs The amount of DS tokens received
     * @param feePercentage The percentage of fees charged
     * @param fee The amount of fees charged
     * @param exchangeRates The exchange rates used in the repurchase
     */
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

    /**
     * @dev Emitted when any type of swap is executed
     * @param caller The address that called the swap function
     * @param swapType The type of swap from the SwapType enum
     * @param inputToken The token address that was swapped (original token provided by user)
     * @param inputAmount The amount of tokens swapped (original amount provided by user)
     * @param outputToken The token address that user received (final token transferred to user)
     * @param outputAmount The amount of tokens user received (final amount transferred to user)
     * @param id The Market identifier for the ModuleCore contract
     * @param dsId The DS-ID from ModuleCore contract if applicable
     * @param minOutput The minimum output amount specified
     * @param maxInput The maximum input amount specified
     * @param unused The amount of tokens that remained unused
     * @param used The amount of tokens that were used
     */
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

    /**
     * @dev Emitted when RA tokens are redeemed using DS and PA tokens
     * @param caller The address that called the redeem function
     * @param paToken The PA token address used in redemption
     * @param paAmount The amount of PA tokens used
     * @param dsToken The DS token address used in redemption
     * @param dsMaxIn The maximum DS tokens to be used
     * @param id The Market identifier for the ModuleCore contract
     * @param dsId The DS-ID from ModuleCore contract used in redemption
     * @param outputToken The token address that user received (final token transferred to user)
     * @param dsUsed The amount of DS tokens actually used
     * @param outAmount The amount of output tokens received
     */
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

    /**
     * @notice Deposits tokens into the PSM (Peg Stability Module)
     * @dev Takes input tokens (any token), swaps them to an accepted protocol token, then deposits into PSM to receive CT/DS tokens
     * @param params The aggregator parameters for the deposit
     * @param id The Market identifier for the ModuleCore contract
     * @return received The amount of CT/DS tokens user received from the deposit
     * @custom:emits DepositPsm event on successful deposit
     * @custom:reverts If the deposit fails
     */
    function depositPsm(AggregatorParams calldata params, Id id) external returns (uint256 received);

    /**
     * @notice Deposits tokens into the PSM (Peg Stability Module) with permit
     * @dev Takes input tokens (any token), swaps them if needed to an accepted protocol token, then deposits into PSM to receive CT/DS tokens
     * @param params The aggregator parameters for the deposit
     * @param id The Market identifier for the ModuleCore contract
     * @param permit The permit data for the deposit
     * @param signature The signature for the permit
     * @return received The amount of CT/DS tokens user received from the deposit
     * @custom:emits DepositPsm event on successful deposit
     * @custom:reverts If the deposit fails
     * @custom:reverts If the permit is invalid
     */
    function depositPsm(
        AggregatorParams calldata params,
        Id id,
        IPermit2.PermitSingle calldata permit,
        bytes calldata signature
    ) external returns (uint256 received);

    /**
     * @notice Deposits tokens into the LV (Liquidity Vault)
     * @dev Takes input tokens (any token), swaps them if needed to an accepted protocol token, then deposits into LV with specified tolerance parameters
     * @param params The aggregator parameters for the deposit
     * @param id The Market identifier for the ModuleCore contract
     * @param raTolerance The tolerance parameter for Redemption Asset (RA)
     * @param ctTolerance The tolerance parameter for Cover Token (CT)
     * @return received The amount of LV tokens user received from the deposit
     * @custom:emits DepositLv event on successful deposit
     * @custom:reverts If the deposit fails
     */
    function depositLv(AggregatorParams calldata params, Id id, uint256 raTolerance, uint256 ctTolerance)
        external
        returns (uint256 received);

    /**
     * @notice Deposits tokens into the LV (Liquidity Vault) with permit
     * @dev Takes input tokens (any token), swaps them if needed to an accepted protocol token, then deposits into LV with specified tolerance parameters
     * @param params The aggregator parameters for the deposit
     * @param id The Market identifier for the ModuleCore contract
     * @param raTolerance The tolerance parameter for Redemption Asset (RA)
     * @param ctTolerance The tolerance parameter for Cover Token (CT)
     * @param permit The permit data for the deposit
     * @param signature The signature for the permit
     * @return received The amount of LV tokens user received from the deposit
     * @custom:emits DepositLv event on successful deposit
     * @custom:reverts If the deposit fails
     * @custom:reverts If the permit is invalid
     */
    function depositLv(
        AggregatorParams calldata params,
        Id id,
        uint256 raTolerance,
        uint256 ctTolerance,
        IPermit2.PermitSingle calldata permit,
        bytes calldata signature
    ) external returns (uint256 received);

    /**
     * @notice Executes a repurchase operation
     * @dev Takes input tokens (any token), swaps them if needed to an accepted protocol token, then repurchases PA and DS tokens
     * @param params The aggregator parameters for the repurchase
     * @param id The Market identifier for the ModuleCore contract
     * @param amount The amount of tokens user wants to repurchase
     * @return result The repurchase results containing PA and DS amounts
     * @custom:emits Repurchase event on successful repurchase
     * @custom:reverts If the repurchase fails
     */
    function repurchase(AggregatorParams calldata params, Id id, uint256 amount)
        external
        returns (RepurchaseReturn memory result);

    /**
     * @notice Executes a repurchase operation with permit
     * @dev Takes input tokens (any token), swaps them if needed to an accepted protocol token, then repurchases PA and DS tokens
     * @param params The aggregator parameters for the repurchase
     * @param id The Market identifier for the ModuleCore contract
     * @param amount The amount of tokens user wants to repurchase
     * @param permit The permit data for the repurchase
     * @param signature The signature for the permit
     * @return result The repurchase results containing PA and DS amounts
     * @custom:emits Repurchase event on successful repurchase
     * @custom:reverts If the repurchase fails
     * @custom:reverts If the permit is invalid
     */
    function repurchase(
        AggregatorParams calldata params,
        Id id,
        uint256 amount,
        IPermit2.PermitSingle calldata permit,
        bytes calldata signature
    ) external returns (RepurchaseReturn memory result);

    /**
     * @notice Swaps Redemption Asset (RA) for Depeg-Swap token (DS)
     * @dev Takes input tokens (any token), swaps them if needed to RA, then swaps RA for DS token via the FlashSwapRouter
     * @param params The parameters for the RA to DS swap
     * @return results The swap results including amount received and fees
     * @custom:emits Swap event with RaForDs swapType
     * @custom:reverts If the swap fails
     */
    function swapRaForDs(SwapRaForDsParams calldata params)
        external
        returns (IDsFlashSwapCore.SwapRaForDsReturn memory results);

    /**
     * @notice Swaps Redemption Asset (RA) for Depeg-Swap token (DS) with permit
     * @dev Takes input tokens (any token), swaps them if needed to RA, then swaps RA for DS token via the FlashSwapRouter
     * @param params The parameters for the RA to DS swap
     * @param permit The permit data for the swap
     * @param signature The signature for the permit
     * @return results The swap results including amount received and fees
     * @custom:emits Swap event with RaForDs swapType
     * @custom:reverts If the swap fails
     * @custom:reverts If the permit is invalid
     */
    function swapRaForDs(
        SwapRaForDsParams calldata params,
        IPermit2.PermitSingle calldata permit,
        bytes calldata signature
    ) external returns (IDsFlashSwapCore.SwapRaForDsReturn memory results);

    /**
     * @notice Swaps Depeg-Swap token (DS) for Redemption Asset (RA)
     * @dev Takes DS tokens and an aggregator params object for final output token, swaps DS to RA, then optionally swaps RA to desired output token
     * @param params The parameters for the DS to RA swap
     * @return amountOut The amount of output tokens received (after optional RA to output token swap)
     * @custom:emits Swap event with DsForRa swapType
     * @custom:reverts If the swap fails
     */
    function swapDsForRa(SwapDsForRaParams memory params) external returns (uint256 amountOut);

    /**
     * @notice Swaps Depeg-Swap token (DS) for Redemption Asset (RA) with permit
     * @dev Takes DS tokens and an aggregator params object for final output token, swaps DS to RA, then optionally swaps RA to desired output token
     * @param params The parameters for the DS to RA swap
     * @param permit The permit data for the swap
     * @param signature The signature for the permit
     * @return amountOut The amount of output tokens received (after optional RA to output token swap)
     * @custom:emits Swap event with DsForRa swapType
     * @custom:reverts If the swap fails
     * @custom:reverts If the permit is invalid
     */
    function swapDsForRa(
        SwapDsForRaParams memory params,
        IPermit2.PermitSingle calldata permit,
        bytes calldata signature
    ) external returns (uint256 amountOut);

    /**
     * @notice Swaps exact amount of Redemption Asset (RA) for Cover Token (CT)
     * @dev Takes input tokens (any token), swaps them if needed to RA, then swaps exact RA amount for CT
     * @param params The aggregator parameters for the swap
     * @param id The Market identifier for the ModuleCore contract
     * @param amountOutMin The minimum amount of CT tokens to receive
     * @return amountOut The amount of CT tokens received
     * @custom:emits Swap event with RaForCtExactIn swapType
     * @custom:reverts If the swap fails or if minimum output amount not met
     */
    function swapRaForCtExactIn(AggregatorParams calldata params, Id id, uint256 amountOutMin)
        external
        returns (uint256 amountOut);

    /**
     * @notice Swaps exact amount of Redemption Asset (RA) for Cover Token (CT) with permit
     * @dev Takes input tokens (any token), swaps them if needed to RA, then swaps exact RA amount for CT
     * @param params The aggregator parameters for the swap
     * @param id The Market identifier for the ModuleCore contract
     * @param amountOutMin The minimum amount of CT tokens to receive
     * @param permit The permit data for the swap
     * @param signature The signature for the permit
     * @return amountOut The amount of CT tokens received
     * @custom:emits Swap event with RaForCtExactIn swapType
     * @custom:reverts If the swap fails, if minimum output amount not met, or if permit is invalid
     */
    function swapRaForCtExactIn(
        AggregatorParams calldata params,
        Id id,
        uint256 amountOutMin,
        IPermit2.PermitSingle calldata permit,
        bytes calldata signature
    ) external returns (uint256 amountOut);

    /**
     * @notice Swaps Redemption Asset (RA) for exact amount of Cover Token (CT)
     * @dev Takes input tokens (any token), swaps them if needed to RA, then swaps RA for exact CT amount
     * @param params The aggregator parameters for the swap
     * @param id The Market identifier for the ModuleCore contract
     * @param amountOut The exact amount of CT tokens to receive
     * @return used The amount of RA tokens used
     * @return remaining The amount of RA tokens remaining unused (refunded to user)
     * @custom:emits Swap event with RaForCtExactOut swapType
     * @custom:reverts If the swap fails or if not enough input tokens to get exact output
     */
    function swapRaForCtExactOut(AggregatorParams calldata params, Id id, uint256 amountOut)
        external
        returns (uint256 used, uint256 remaining);

    /**
     * @notice Swaps Redemption Asset (RA) for exact amount of Cover Token (CT) with permit
     * @dev Takes input tokens (any token), swaps them if needed to RA, then swaps RA for exact CT amount
     * @param params The aggregator parameters for the swap
     * @param id The Market identifier for the ModuleCore contract
     * @param amountOut The exact amount of CT tokens to receive
     * @param permit The permit data for the swap
     * @param signature The signature for the permit
     * @return used The amount of RA tokens used
     * @return remaining The amount of RA tokens remaining unused (refunded to user)
     * @custom:emits Swap event with RaForCtExactOut swapType
     * @custom:reverts If the swap fails, if not enough input tokens, or if permit is invalid
     */
    function swapRaForCtExactOut(
        AggregatorParams calldata params,
        Id id,
        uint256 amountOut,
        IPermit2.PermitSingle calldata permit,
        bytes calldata signature
    ) external returns (uint256 used, uint256 remaining);

    /**
     * @notice Swaps exact amount of Cover Token (CT) for Redemption Asset (RA) and optionally to another output token
     * @dev Takes exact CT amount and swaps to RA, then optionally swaps RA to desired output token using aggregator params
     * @param params The aggregator parameters for the optional RA to output token swap
     * @param id The Market identifier for the ModuleCore contract
     * @param ctAmount The exact amount of CT tokens to swap
     * @param raAmountOutMin The minimum amount of RA tokens to receive before optional swap
     * @return amountOut The amount of output tokens received (after optional RA swap)
     * @custom:emits Swap event with CtForRaExactIn swapType
     * @custom:reverts If the swap fails or if minimum output amount not met
     */
    function swapCtForRaExactIn(AggregatorParams memory params, Id id, uint256 ctAmount, uint256 raAmountOutMin)
        external
        returns (uint256 amountOut);

    /**
     * @notice Swaps exact amount of Cover Token (CT) for Redemption Asset (RA) and optionally to another output token with permit
     * @dev Takes exact CT amount and swaps to RA, then optionally swaps RA to desired output token using aggregator params
     * @param params The aggregator parameters for the optional RA to output token swap
     * @param id The Market identifier for the ModuleCore contract
     * @param ctAmount The exact amount of CT tokens to swap
     * @param raAmountOutMin The minimum amount of RA tokens to receive before optional swap
     * @param permit The permit data for the swap
     * @param signature The signature for the permit
     * @return amountOut The amount of output tokens received (after optional RA swap)
     * @custom:emits Swap event with CtForRaExactIn swapType
     * @custom:reverts If the swap fails, if minimum output amount not met, or if permit is invalid
     */
    function swapCtForRaExactIn(
        AggregatorParams memory params,
        Id id,
        uint256 ctAmount,
        uint256 raAmountOutMin,
        IPermit2.PermitSingle calldata permit,
        bytes calldata signature
    ) external returns (uint256 amountOut);

    /**
     * @notice Swaps Cover Token (CT) for exact amount of Redemption Asset (RA) and optionally to another output token
     * @dev Takes CT tokens and swaps for exact RA amount, then optionally swaps RA to desired output token using aggregator params
     * @param params The aggregator parameters for the optional RA to output token swap
     * @param id The Market identifier for the ModuleCore contract
     * @param rAmountOut The exact amount of RA tokens to receive before optional swap
     * @param amountInMax The maximum amount of CT tokens to spend
     * @return ctUsed The amount of CT tokens used
     * @return ctRemaining The amount of CT tokens remaining unused (refunded to user)
     * @return tokenOutAmountOut The actual amount of output tokens received (after optional RA swap)
     * @custom:emits Swap event with CtForRaExactOut swapType
     * @custom:reverts If the swap fails or if not enough input tokens to get exact output
     */
    function swapCtForRaExactOut(AggregatorParams memory params, Id id, uint256 rAmountOut, uint256 amountInMax)
        external
        returns (uint256 ctUsed, uint256 ctRemaining, uint256 tokenOutAmountOut);

    /**
     * @notice Swaps Cover Token (CT) for exact amount of Redemption Asset (RA) and optionally to another output token with permit
     * @dev Takes CT tokens and swaps for exact RA amount, then optionally swaps RA to desired output token using aggregator params
     * @param params The aggregator parameters for the optional RA to output token swap
     * @param id The Market identifier for the ModuleCore contract
     * @param rAmountOut The exact amount of RA tokens to receive before optional swap
     * @param amountInMax The maximum amount of CT tokens to spend
     * @param permit The permit data for the swap
     * @param signature The signature for the permit
     * @return ctUsed The amount of CT tokens used
     * @return ctRemaining The amount of CT tokens remaining unused (refunded to user)
     * @return tokenOutAmountOut The actual amount of output tokens received (after optional RA swap)
     * @custom:emits Swap event with CtForRaExactOut swapType
     * @custom:reverts If the swap fails, if not enough input tokens, or if permit is invalid
     */
    function swapCtForRaExactOut(
        AggregatorParams memory params,
        Id id,
        uint256 rAmountOut,
        uint256 amountInMax,
        IPermit2.PermitSingle calldata permit,
        bytes calldata signature
    ) external returns (uint256 ctUsed, uint256 ctRemaining, uint256 tokenOutAmountOut);

    /**
     * @notice Redeems output tokens using Depeg-Swap (DS) and PA tokens
     * @dev Takes input tokens (any token), swaps them if needed to PA, combines with DS to redeem RA, then optionally swaps RA to desired output token
     * @param zapInParams The aggregator parameters for swapping input to PA
     * @param zapOutParams The aggregator parameters for optionally swapping redeemed RA to output token
     * @param id The Market identifier for the ModuleCore contract
     * @param dsMaxIn The maximum amount of DS tokens to use
     * @return dsUsed The amount of DS tokens actually used
     * @return outAmount The amount of output tokens received
     * @custom:emits RedeemRaWithDsPa event on successful redemption
     * @custom:reverts If ZapIn or ZapOut fails
     * @custom:reverts If the redemption fails
     */
    function redeemRaWithDsPa(
        AggregatorParams calldata zapInParams,
        AggregatorParams memory zapOutParams,
        Id id,
        uint256 dsMaxIn
    ) external returns (uint256 dsUsed, uint256 outAmount);

    /**
     * @notice Redeems output tokens using Depeg-Swap (DS) and PA tokens with permit
     * @dev Takes input tokens (any token), swaps them if needed to PA, combines with DS to redeem RA, then optionally swaps RA to desired output token
     * @param zapInParams The aggregator parameters for swapping input to PA
     * @param zapOutParams The aggregator parameters for optionally swapping redeemed RA to output token
     * @param id The Market identifier for the ModuleCore contract
     * @param dsMaxIn The maximum amount of DS tokens to use
     * @param permit The permit data for the redemption
     * @param signature The signature for the permit
     * @return dsUsed The amount of DS tokens actually used
     * @return outAmount The amount of output tokens received
     * @custom:emits RedeemRaWithDsPa event on successful redemption
     * @custom:reverts If ZapIn or ZapOut fails
     * @custom:reverts If the redemption fails
     * @custom:reverts If the permit is invalid
     */
    function redeemRaWithDsPa(
        AggregatorParams calldata zapInParams,
        AggregatorParams memory zapOutParams,
        Id id,
        uint256 dsMaxIn,
        IPermit2.PermitBatch calldata permit,
        bytes calldata signature
    ) external returns (uint256 dsUsed, uint256 outAmount);
}

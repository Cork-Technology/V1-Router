// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {ICorkSwapAggregator} from "../interfaces/ICorkSwapAggregator.sol";
import {IMetaAggregationRouterV2} from "../interfaces/IMetaAggregationRouter.sol";
import {TransferHelper} from "../lib/TransferHelper.sol";

contract CorkSwapAggregator is ReentrancyGuardTransient, ICorkSwapAggregator {
    using TransferHelper for address;

    address public immutable KYBER_ROUTER;

    // KyberSwap flags
    uint256 internal constant _APPROVE_FUND = 0x100;

    constructor(address _kyberRouter) {
        if (_kyberRouter == address(0)) {
            revert ZeroAddress();
        }
        KYBER_ROUTER = _kyberRouter;
    }

    function swap(AggregatorParams calldata params) external override nonReentrant returns (uint256 amountOut) {
        // Transfer tokens from sender to this contract
        params.tokenIn.safeTransferFrom(msg.sender, address(this), params.amountIn);

        // Decode extRouterData to get necessary KyberSwap parameters
        (address callTarget, address approveTarget, bytes memory targetData, uint256 flags) =
            abi.decode(params.extRouterData, (address, address, bytes, uint256));

        // Approve KyberSwap router or approveTarget to spend these tokens
        address approveAddress = approveTarget == address(0) ? KYBER_ROUTER : approveTarget;
        params.tokenIn.safeApprove(approveAddress, params.amountIn);

        // Prepare the swap description for KyberSwap
        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc = IMetaAggregationRouterV2.SwapDescriptionV2({
            srcToken: params.tokenIn,
            dstToken: params.tokenOut,
            srcReceivers: new address[](1),
            srcAmounts: new uint256[](1),
            feeReceivers: new address[](0),
            feeAmounts: new uint256[](0),
            dstReceiver: address(this), // Always receive to this contract first
            amount: params.amountIn,
            minReturnAmount: params.amountOutMin,
            flags: flags, // Use the flags passed from extRouterData
            permit: new bytes(0)
        });

        // Set receiver according to the flags
        if ((flags & _APPROVE_FUND) != 0) {
            // If APPROVE_FUND is set, the kyberRouter will use allowance
            desc.srcReceivers[0] = address(this);
        } else {
            // Otherwise, funds should be sent to the call target
            desc.srcReceivers[0] = callTarget;
        }
        desc.srcAmounts[0] = params.amountIn;

        // Create swap execution parameters
        IMetaAggregationRouterV2.SwapExecutionParams memory executionParams = IMetaAggregationRouterV2
            .SwapExecutionParams({
            callTarget: callTarget,
            approveTarget: approveTarget,
            targetData: targetData,
            desc: desc,
            clientData: ""
        });

        // Execute the swap
        (amountOut,) = IMetaAggregationRouterV2(KYBER_ROUTER).swap(executionParams);

        // Transfer the swapped tokens back to the sender
        params.tokenOut.safeTransfer(msg.sender, amountOut);
        return amountOut;
    }
}

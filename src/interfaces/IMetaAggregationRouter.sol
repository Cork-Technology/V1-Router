// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface MetaAggregationRouterV2 {
    struct SwapDescriptionV2 {
        address srcToken;
        address dstToken;
        address[] srcReceivers;
        uint256[] srcAmounts;
        address[] feeReceivers;
        uint256[] feeAmounts;
        address dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
        bytes permit;
    }

    struct SwapExecutionParams {
        address callTarget;
        address approveTarget;
        bytes targetData;
        SwapDescriptionV2 desc;
        bytes clientData;
    }

    function swap(SwapExecutionParams memory execution)
        external
        payable
        returns (uint256 returnAmount, uint256 gasUsed);

    function swapGeneric(SwapExecutionParams memory execution)
        external
        payable
        returns (uint256 returnAmount, uint256 gasUsed);

    function swapSimpleMode(
        address caller,
        SwapDescriptionV2 memory desc,
        bytes memory executorData,
        bytes memory clientData
    ) external returns (uint256 returnAmount, uint256 gasUsed);
}

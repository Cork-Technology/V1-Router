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

    event ClientData(bytes clientData);

    event Error(string reason);

    event Exchange(address pair, uint256 amountOut, address output);
    
    event Fee(
        address token, uint256 totalAmount, uint256 totalFee, address[] recipients, uint256[] amounts, bool isBps
    );
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    event Swapped(
        address sender,
        address srcToken,
        address dstToken,
        address dstReceiver,
        uint256 spentAmount,
        uint256 returnAmount
    );

    receive() external payable;

    function WETH() external view returns (address);
    
    function isWhitelist(address) external view returns (bool);
    
    function owner() external view returns (address);
    
    function renounceOwnership() external;
    
    function rescueFunds(address token, uint256 amount) external;
   
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
   
    function transferOwnership(address newOwner) external;
   
    function updateWhitelist(address[] memory addr, bool[] memory value) external;
}

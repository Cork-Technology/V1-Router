pragma solidity ^0.8.28;

import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

library TransferHelper {
    using SafeERC20 for IERC20;

    function approve(address token, address to, uint256 value) internal {
        IERC20(token).safeIncreaseAllowance(to, value);
    }

    function transfer(address token, address to, uint256 value) internal {
        IERC20(token).safeTransfer(to, value);
    }

    function transferFrom(address token, address from, address to, uint256 value) internal {
        IERC20(token).safeTransferFrom(from, to, value);
    }
}

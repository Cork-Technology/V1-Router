// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

library TransferHelper {
    using SafeERC20 for IERC20;

    function safeApprove(address token, address to, uint256 value) internal {
        IERC20(token).safeIncreaseAllowance(to, value);
    }

    function safeTransfer(address token, address to, uint256 value) internal {
        IERC20(token).safeTransfer(to, value);
    }

    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        IERC20(token).safeTransferFrom(from, to, value);
    }

    function safeRevockAllowance(address token, address to) internal {
        uint256 currentAllowance = IERC20(token).allowance(address(this), to);
        IERC20(token).safeDecreaseAllowance(to, currentAllowance);
    }
}

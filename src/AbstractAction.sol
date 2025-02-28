// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IPSMcore} from "Depeg-swap/contracts/interfaces/IPSMcore.sol";
import {IVault} from "Depeg-swap/contracts/interfaces/IVault.sol";
import {Initialize} from "Depeg-swap/contracts/interfaces/Init.sol";
import {ICorkHook} from "Cork-Hook/interfaces/ICorkHook.sol";
import {State} from "./State.sol";
import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {TransferHelper} from "./lib/TransferHelper.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ICorkSwapAggregator} from "./interfaces/ICorkSwapAggregator.sol";

abstract contract AbtractAction is State {
    function _transferFromUser(address token, uint256 amount) internal {
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amount);
    }

    function _increaseAllowanceForProtocol(address token, uint256 amount) internal {
        _increaseAllowance(token, CORE, amount);
    }

    function _increaseAllowance(address token, address to, uint256 amount) internal {
        TransferHelper.safeApprove(token, to, amount);
    }

    function _transferToUser(address token, uint256 amount) internal {
        TransferHelper.safeTransfer(token, msg.sender, amount);
    }

    function _contractBalance(address token) internal view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function _transferAllCtDsToUser(Id id) internal {
        Initialize core = Initialize(CORE);

        uint256 dsId = core.lastDsId(id);
        (address ct, address ds) = core.swapAsset(id, dsId);

        _transferToUser(ct, _contractBalance(ct));
        _transferToUser(ds, _contractBalance(ds));
    }

    function _transferAllLvToUser(Id id) internal {
        address lv = _vault().lvAsset(id);

        _transferToUser(lv, _contractBalance(lv));
    }

    function _swap(ICorkSwapAggregator.SwapParams calldata params) internal returns (uint256) {
        _transferFromUser(params.tokenIn, params.amountIn);

        _increaseAllowance(params.tokenIn, params.extRouter, params.amountIn);
        return ICorkSwapAggregator(params.extRouter).swap(params);
    }
}

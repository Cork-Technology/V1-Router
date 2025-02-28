pragma solidity ^0.8.26;

import {IPSMcore} from "Depeg-swap/contracts/interfaces/IPSMcore.sol";
import {IVault} from "Depeg-swap/contracts/interfaces/IVault.sol";
import {Initialize} from "Depeg-swap/contracts/interfaces/Init.sol";
import {ICorkHook} from "Cork-Hook/interfaces/ICorkHook.sol";
import {State} from "./State.sol";
import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";
import {TransferHelper} from "./lib/TransferHelper.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ERC20Burnable} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ICorkSwapAggregator} from "./interfaces/ICorkSwapAggregator.sol";
import {IWithdrawalRouter} from "Depeg-swap/contracts/interfaces/IWithdrawalRouter.sol";
import {Asset} from "Depeg-swap/contracts/core/assets/Asset.sol";

abstract contract AbtractAction is State {
    function _transferFromUser(address token, uint256 amount) internal {
        TransferHelper.transferFrom(token, msg.sender, address(this), amount);
    }

    function _increaseAllowanceForProtocol(address token, uint256 amount) internal {
        _increaseAllowance(token, CORE, amount);
    }

    function _increaseAllowance(address token, address to, uint256 amount) internal {
        TransferHelper.approve(token, to, amount);
    }

    function _transferToUser(address token, uint256 amount) internal {
        _transfer(token, msg.sender, amount);
    }

    function _transfer(address token, address to, uint256 amount) internal {
        TransferHelper.transfer(token, to, amount);
    }

    function _contractBalance(address token) internal view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function _transferAllCtDsToUser(Id id) internal {
        (address ct, address ds) = __getCtDs(id);

        _transferToUser(ct, _contractBalance(ct));
        _transferToUser(ds, _contractBalance(ds));
    }

    function _transferAllLvToUser(Id id) internal {
        address lv = _vault().lvAsset(id);

        _transferToUser(lv, _contractBalance(lv));
    }

    function __getCtDs(Id id) internal view returns (address ct, address ds) {
        Initialize core = Initialize(CORE);
        uint256 dsId = core.lastDsId(id);
        (ct, ds) = __getCtDs(id, dsId);
    }

    function __getRaPair(Id id) internal view returns (address ra, address pa) {
        Initialize core = Initialize(CORE);
        (ra, pa) = core.underlyingAsset(id);
    }

    function __getCtDs(Id id, uint256 dsId) internal view returns (address ct, address ds) {
        Initialize core = Initialize(CORE);

        (ct, ds) = core.swapAsset(id, dsId);
    }

    function _swap(ICorkSwapAggregator.SwapParams memory params) internal returns (uint256) {
        _transferFromUser(params.tokenIn, params.amountIn);

        _increaseAllowance(params.tokenIn, params.extRouter, params.amountIn);
        return ICorkSwapAggregator(params.extRouter).swap(params);
    }

    function __findCtDsFromTokens(IWithdrawalRouter.Tokens[] calldata tokens, Id id)
        internal
        view
        returns (address ct, address ds, uint256 dsId)
    {
        for (uint256 i = 0; i < tokens.length; i++) {
            try Asset(tokens[i].token).dsId() returns (uint256 _dsId) {
                dsId = _dsId;
                (ct, ds) = __getCtDs(id, dsId);

                return (ct, ds, dsId);

                // solhint-disable-next-line no-empty-blocks
            } catch {}
        }
        // TODO : move to interface as custom errors
        revert("Invalid tokens");
    }

    function _handleLvRedeemDsExpired(Id id, address ct, address ds, uint256 dsId, address user) internal {
        (address ra,) = __getRaPair(id);

        ERC20Burnable(ds).burn(_contractBalance(ds));

        _increaseAllowanceForProtocol(ct, _contractBalance(ct));

        _psm().redeemWithExpiredCt(id, dsId, _contractBalance(ct));

        _transfer(ra, user, _contractBalance(ra));
    }

    function _handleLvRedeem(IWithdrawalRouter.Tokens[] calldata tokens, bytes calldata params, address user)
        internal
    {
        ICorkSwapAggregator.RouterParams memory routerParams = abi.decode(params, (ICorkSwapAggregator.RouterParams));

        _swap(routerParams.paSwapAggregatorData);

        (address ct, address ds, uint256 dsId) = __findCtDsFromTokens(tokens, routerParams.id);

        if (Asset(ct).isExpired()) {
            _handleLvRedeemDsExpired(routerParams.id, ct, ds, dsId, user);
        } else {
            _handleLvRedeemDsActive(routerParams.id, ct, ds, dsId, routerParams.dsMinOut, user);
        }
    }

    function _handleLvRedeemDsActive(Id id, address ct, address ds, uint256 dsId, uint256 amountOutMin, address user)
        internal
    {
        uint256 ctBalance = _contractBalance(ct);
        uint256 dsBalance = _contractBalance(ds);

        (uint256 redeemAmount, bool isCt, uint256 diff) =
            ctBalance > dsBalance ? (dsBalance, false, ctBalance - dsBalance) : (ctBalance, true, dsBalance - ctBalance);

        _psm().returnRaWithCtDs(id, redeemAmount);

        (address ra,) = __getRaPair(id);

        // sell remaining CT or DS
        if (isCt) {
            uint256 amountOut = _hook().getAmountOut(ra, ct, false, diff);

            // no data since we won't be doing flash swap
            _hook().swap(ra, ct, amountOut, 0, bytes(""));
        } else {
            _flashSwapRouter().swapDsforRa(id, dsId, diff, amountOutMin);
        }

        _transfer(ra, user, _contractBalance(ra));
    }
}

pragma solidity ^0.8.26;

import {State} from "./State.sol";
import {AbtractAction} from "./AbstractAction.sol";
import {TransferHelper} from "./lib/TransferHelper.sol";
import {ICorkSwapAggregator} from "./interfaces/ICorkSwapAggregator.sol";
import {Id} from "Depeg-swap/contracts/libraries/Pair.sol";

contract CorkRouterV1 is State, AbtractAction {
    using TransferHelper for address;

    constructor(address __core, address __flashSwapRouter, address __hook) State(__core, __flashSwapRouter, __hook) {}

    function depositPsm(ICorkSwapAggregator.SwapParams calldata params, Id id) external returns (uint256 amount) {
        uint256 amount = _swap(params);

        _increaseAllowanceForProtocol(params.tokenOut, amount);

        (amount,) = _psm().depositPsm(id, amount);

        _transferAllCtDsToUser(id);
    }

    function depositLv(ICorkSwapAggregator.SwapParams calldata params, Id id, uint256 raTolerance, uint256 ctTolerance)
        external
    {
        uint256 amount = _swap(params);

        _increaseAllowanceForProtocol(params.tokenOut, amount);
        _vault().depositLv(id, amount, raTolerance, ctTolerance);

        _transferAllLvToUser(id);
    }
}

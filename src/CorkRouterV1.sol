pragma solidity ^0.8.28;

import {State} from "./State.sol";
import {TransferHelper} from "./lib/TransferHelper.sol";

contract CorkRouterV1 is State {
    using TransferHelper for address;

    constructor(address __core, address __flashSwapRouter, address __hook) State(__core, __flashSwapRouter, __hook) {}
}

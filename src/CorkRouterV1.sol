pragma solidity ^0.8.28;

import {State} from "./State.sol";

contract CorkRouterV1 is State {
    constructor(address __core, address __flashSwapRouter, address __hook) State(__core, __flashSwapRouter, __hook) {}
}

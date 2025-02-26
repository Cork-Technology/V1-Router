pragma solidity ^0.8.28;

import {IPSMcore} from "Depeg-swap/contracts/interfaces/IPSMcore.sol";
import {IVault} from "Depeg-swap/contracts/interfaces/IVault.sol";
import {ICorkHook} from "Cork-Hook/interfaces/ICorkHook.sol";
import {MetaAggregationRouterV2} from "./interfaces/IMetaAggregationRouter.sol";

abstract contract State {
    address public immutable CORE;
    address public immutable FLASH_SWAP_ROUTER;
    address public immutable HOOK;
    address public immutable KYBERSWAP_ROUTER;

    constructor(address __core, address __flashSwapRouter, address __hook, address __kyberSwapRouter) {
        CORE = __core;
        FLASH_SWAP_ROUTER = __flashSwapRouter;
        HOOK = __hook;
        KYBERSWAP_ROUTER = __kyberSwapRouter;
    }

    function _vault() internal view returns (IVault) {
        return IVault(CORE);
    }

    function _core() internal view returns (IPSMcore) {
        return IPSMcore(CORE);
    }

    function _hook() internal view returns (ICorkHook) {
        return ICorkHook(HOOK);
    }

    function _converter() internal view returns (MetaAggregationRouterV2) {
        return MetaAggregationRouterV2(KYBERSWAP_ROUTER);
    }
}

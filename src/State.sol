pragma solidity ^0.8.26;

import {IPSMcore} from "Depeg-swap/contracts/interfaces/IPSMcore.sol";
import {IVault} from "Depeg-swap/contracts/interfaces/IVault.sol";
import {ICorkHook} from "Cork-Hook/interfaces/ICorkHook.sol";
import {IDsFlashSwapCore} from "Depeg-swap/contracts/interfaces/IDsFlashSwapRouter.sol";

abstract contract State {
    address public immutable CORE;
    address public immutable FLASH_SWAP_ROUTER;
    address public immutable HOOK;

    constructor(address __core, address __flashSwapRouter, address __hook) {
        CORE = __core;
        FLASH_SWAP_ROUTER = __flashSwapRouter;
        HOOK = __hook;
    }

    function _vault() internal view returns (IVault) {
        return IVault(CORE);
    }

    function _psm() internal view returns (IPSMcore) {
        return IPSMcore(CORE);
    }

    function _hook() internal view returns (ICorkHook) {
        return ICorkHook(HOOK);
    }

    function _flashSwapRouter() internal view returns (IDsFlashSwapCore) {
        return IDsFlashSwapCore(FLASH_SWAP_ROUTER);
    }
}

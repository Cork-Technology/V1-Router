// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IPSMcore} from "Depeg-swap/contracts/interfaces/IPSMcore.sol";
import {IVault} from "Depeg-swap/contracts/interfaces/IVault.sol";
import {ICorkHook} from "Cork-Hook/interfaces/ICorkHook.sol";
import {IDsFlashSwapCore} from "Depeg-swap/contracts/interfaces/IDsFlashSwapRouter.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";

abstract contract State is OwnableUpgradeable, UUPSUpgradeable {
    address public core;
    address public flashSwapRouter;
    address public hook;

    constructor() {
        _disableInitializers();
    }

    function initialize(address __core, address __flashSwapRouter, address __hook, address _owner) external initializer {
        __Ownable_init(_owner);

        core = __core;
        flashSwapRouter = __flashSwapRouter;
        hook = __hook;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function _vault() internal view returns (IVault) {
        return IVault(core);
    }

    function _psm() internal view returns (IPSMcore) {
        return IPSMcore(core);
    }

    function _hook() internal view returns (ICorkHook) {
        return ICorkHook(hook);
    }

    function _flashSwapRouter() internal view returns (IDsFlashSwapCore) {
        return IDsFlashSwapCore(flashSwapRouter);
    }
}

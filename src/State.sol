// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IPSMcore} from "Depeg-swap/contracts/interfaces/IPSMcore.sol";
import {IVault} from "Depeg-swap/contracts/interfaces/IVault.sol";
import {ICorkHook} from "Cork-Hook/interfaces/ICorkHook.sol";
import {IDsFlashSwapCore} from "Depeg-swap/contracts/interfaces/IDsFlashSwapRouter.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {ICommon} from "./interfaces/ICommon.sol";

abstract contract State is ReentrancyGuardTransient, OwnableUpgradeable, UUPSUpgradeable, ICommon {
    address public core;
    address public flashSwapRouter;
    address public hook;
    address public permit2;

    /// @notice __gap variable to prevent storage collisions
    // slither-disable-next-line unused-state
    uint256[49] private __gap;

    constructor() {
        _disableInitializers();
    }

    function initialize(address __core, address __flashSwapRouter, address __hook, address __permit2, address _owner)
        external
        initializer
    {
        if (
            __core == address(0) || __flashSwapRouter == address(0) || __hook == address(0) || __permit2 == address(0)
                || _owner == address(0)
        ) {
            revert ZeroAddress();
        }
        __Ownable_init(_owner);

        core = __core;
        flashSwapRouter = __flashSwapRouter;
        hook = __hook;
        permit2 = __permit2;
    }

    /// @notice function for UUPS proxy upgrades with owner only access
    // solhint-disable-next-line no-empty-blocks
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

    function _permit2() internal view returns (IPermit2) {
        return IPermit2(permit2);
    }
}

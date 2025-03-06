// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

interface IAbstractAction {
    /// @notice Thrown when the tokens are invalid
    error InvalidTokens();

    /// @notice Thrown when non-manager calls the unlockCallback
    error OnlyManager();
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPermit2} from "permit2/interfaces/IPermit2.sol";
import {IAllowanceTransfer} from "permit2/interfaces/IAllowanceTransfer.sol";
import {Test} from "forge-std/Test.sol";

/// @title SigUtil
/// @notice Utility contract for cryptographic signature operations
contract SigUtil is Test {
    bytes32 internal constant PERMIT_SINGLE_TYPEHASH = keccak256(
        "PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
    );

    bytes32 internal constant PERMIT_DETAILS_TYPEHASH =
        keccak256("PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)");

    /// @notice Generate a signature for a Permit2 PermitSingle in a single call
    /// @param permit The permit single structure to sign
    /// @param privateKey The private key to sign with
    /// @param permit2Address Optional custom Permit2 address (uses default if address(0))
    /// @return The signature as a bytes value
    function signPermit2(IAllowanceTransfer.PermitSingle memory permit, uint256 privateKey, address permit2Address)
        public
        view
        returns (bytes memory)
    {
        IPermit2 permit2 = IPermit2(permit2Address);
        bytes32 digest = getPermit2TypedDataHash(permit, permit2);
        return signDigest(digest, privateKey);
    }

    /// @notice Generate EIP-712 typed data hash for Permit2 PermitSingle
    /// @param permit The permit single structure
    /// @param permit2 The Permit2 contract
    /// @return The EIP-712 typed data hash to be signed
    function getPermit2TypedDataHash(IAllowanceTransfer.PermitSingle memory permit, IPermit2 permit2)
        internal
        view
        returns (bytes32)
    {
        bytes32 DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();

        // Hash the permit details struct
        bytes32 permitDetailsHash = keccak256(abi.encode(PERMIT_DETAILS_TYPEHASH, permit.details));

        // Hash the complete struct
        bytes32 structHash =
            keccak256(abi.encode(PERMIT_SINGLE_TYPEHASH, permitDetailsHash, permit.spender, permit.sigDeadline));

        // Create the final EIP-712 digest
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    }

    /// @notice Create a signature from a digest using a private key
    /// @param digest The message digest to sign
    /// @param privateKey The private key to sign with
    /// @return The signature as a bytes value
    function signDigest(bytes32 digest, uint256 privateKey) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}

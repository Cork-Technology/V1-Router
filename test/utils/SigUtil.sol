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

    bytes32 internal constant PERMIT_BATCH_TYPEHASH = keccak256(
        "PermitBatch(PermitDetails[] details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
    );

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

    /// @notice Generate EIP-712 typed data hash for Permit2 PermitBatch
    /// @param permit The permit batch structure
    /// @param permit2 The Permit2 contract
    /// @return The EIP-712 typed data hash to be signed
    function getPermitBatchTypedDataHash(IAllowanceTransfer.PermitBatch memory permit, IPermit2 permit2)
        internal
        view
        returns (bytes32)
    {
        bytes32 DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();

        // Hash each permit details struct
        bytes32[] memory permitDetailsHashes = new bytes32[](permit.details.length);
        for (uint256 i = 0; i < permit.details.length; i++) {
            permitDetailsHashes[i] = keccak256(abi.encode(PERMIT_DETAILS_TYPEHASH, permit.details[i]));
        }

        // Hash the array of details
        bytes32 detailsHash = keccak256(abi.encodePacked(permitDetailsHashes));

        // Hash the complete struct
        bytes32 structHash =
            keccak256(abi.encode(PERMIT_BATCH_TYPEHASH, detailsHash, permit.spender, permit.sigDeadline));

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

    /// @notice Creates a Permit2 permit and signature in one convenient call
    /// @param token The token address to approve
    /// @param amount The amount to approve
    /// @param spender The address that will spend the tokens
    /// @param privateKey The private key to sign with
    /// @param permit2Address The Permit2 contract address
    /// @param nonce Optional nonce value
    /// @param deadline Optional permit deadline (defaults to 1 hour from now)
    /// @return permit The constructed PermitSingle struct
    /// @return signature The signature bytes
    function createPermitAndSignature(
        address token,
        uint256 amount,
        address spender,
        uint256 privateKey,
        address permit2Address,
        uint48 nonce,
        uint256 deadline
    ) public view returns (IAllowanceTransfer.PermitSingle memory permit, bytes memory signature) {
        if (deadline == 0) {
            deadline = block.timestamp + 1 hours;
        }

        // Create the permit structure
        permit = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: token,
                amount: uint160(amount),
                expiration: uint48(deadline),
                nonce: nonce
            }),
            spender: spender,
            sigDeadline: deadline
        });

        // Generate the signature
        signature = signPermit2(permit, privateKey, permit2Address);

        return (permit, signature);
    }

    /// @notice Simplified version with default values
    /// @param token The token address to approve
    /// @param amount The amount to approve
    /// @param spender The address that will spend the tokens
    /// @param privateKey The private key to sign with
    /// @param permit2Address The Permit2 contract address
    /// @return permit The constructed PermitSingle struct
    /// @return signature The signature bytes
    function createPermitAndSignature(
        address token,
        uint256 amount,
        address spender,
        uint256 privateKey,
        address permit2Address
    ) public view returns (IAllowanceTransfer.PermitSingle memory permit, bytes memory signature) {
        return
            createPermitAndSignature(token, amount, spender, privateKey, permit2Address, 0, block.timestamp + 1 hours);
    }

    /// @notice Creates a Permit2 batch permit and signature in one convenient call
    /// @param tokens Array of token addresses to approve
    /// @param amounts Array of amounts to approve for each token
    /// @param spender The address that will spend the tokens
    /// @param privateKey The private key to sign with
    /// @param permit2Address The Permit2 contract address
    /// @param deadline Optional permit deadline (defaults to 1 hour from now)
    /// @return permit The constructed PermitBatch struct
    /// @return signature The signature bytes
    function createBatchPermitAndSignature(
        address[] memory tokens,
        uint256[] memory amounts,
        address spender,
        uint256 privateKey,
        address permit2Address,
        uint256 deadline
    ) public view returns (IAllowanceTransfer.PermitBatch memory permit, bytes memory signature) {
        require(tokens.length == amounts.length, "Array lengths must match");

        if (deadline == 0) {
            deadline = block.timestamp + 1 hours;
        }

        // Create the permit details
        IAllowanceTransfer.PermitDetails[] memory details = new IAllowanceTransfer.PermitDetails[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            details[i] = IAllowanceTransfer.PermitDetails({
                token: tokens[i],
                amount: uint160(amounts[i]),
                expiration: uint48(deadline),
                nonce: 0
            });
        }

        // Create the batch permit
        permit = IAllowanceTransfer.PermitBatch({details: details, spender: spender, sigDeadline: deadline});

        // Generate and sign the typed data hash
        bytes32 digest = getPermitBatchTypedDataHash(permit, IPermit2(permit2Address));
        signature = signDigest(digest, privateKey);

        return (permit, signature);
    }

    /// @notice Simplified version with default deadline
    function createBatchPermitAndSignature(
        address[] memory tokens,
        uint256[] memory amounts,
        address spender,
        uint256 privateKey,
        address permit2Address
    ) public view returns (IAllowanceTransfer.PermitBatch memory permit, bytes memory signature) {
        return createBatchPermitAndSignature(
            tokens, amounts, spender, privateKey, permit2Address, block.timestamp + 1 hours
        );
    }
}

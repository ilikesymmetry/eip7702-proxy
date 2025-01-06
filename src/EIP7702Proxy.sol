// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Proxy} from "openzeppelin-contracts/contracts/proxy/Proxy.sol";
import {ERC1967Utils} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

/// @notice Proxy contract designed for EIP-7702 smart accounts.
///
/// @dev Implements ERC-1967, but with an initial implementation.
/// @dev Guards the initializer function, requiring a signed payload by the wallet to call it.
contract EIP7702Proxy is Proxy {
    address immutable proxy;
    address immutable initialImplementation;
    bytes4 immutable guardedInitializer;

    error InvalidSignature();
    error InvalidInitializer();

    constructor(address implementation, bytes4 initializer) {
        proxy = address(this);
        initialImplementation = implementation;
        guardedInitializer = initializer;
    }

    function initialize(bytes calldata args, bytes calldata signature) external {
        bytes32 hash = keccak256(abi.encode(proxy, args));
        address recovered = ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(hash), signature);
        if (recovered != address(this)) revert InvalidSignature();

        Address.functionDelegateCall(initialImplementation, abi.encodePacked(guardedInitializer, args));
    }

    function _implementation() internal view override returns (address) {
        address implementation = ERC1967Utils.getImplementation();
        return implementation != address(0) ? implementation : initialImplementation;
    }

    function _fallback() internal override {
        if (msg.sig == guardedInitializer) revert InvalidInitializer();
        _delegate(_implementation());
    }
}

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;

library Constants {
    // keccak256(abi.encode(uint256(keccak256("operator.state")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant OPERATOR_STORAGE_PREFIX = 0x06681591129b3aa7eb104d08465908202aa06b00156da6fb6f3a2c0461660700;
}

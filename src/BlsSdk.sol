// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import "forge-std/console.sol";
import {BN254} from "./utils/BN254.sol";

library BlsSdk {
    using BN254 for BN254.G1Point;

    ///@notice the user of the library should initiate a storage variable that has been built on this struct
    struct State {
        mapping(address operatorAddress => bool exists) operatorExists;
        mapping(address operatorAddress => uint256 index) operatorIndex;
        address[] operatorAddresses;
        address aggregator;
        BN254.G1Point aggregatedG1Pubkey;
        mapping(address operator => BN254.G1Point) operatorG1Pubkey;
        BN254.G1Point[] allOperatorPubkeyG1;
    }

    ///@notice performs registration
    ///@param state the state in which registration will take place
    ///@param operator address of the operator that will be registered
    ///@param extraData an abi encoded bytes field that contains g1 pubkey, g2 pubkey, message hash and the signature
    function operatorRegistration(State storage state, address operator, bytes memory extraData) external {
        (BN254.G1Point memory g1Pubkey, BN254.G2Point memory g2Pubkey, bytes32 msgHash, BN254.G1Point memory sign) =
            abi.decode(extraData, (BN254.G1Point, BN254.G2Point, bytes32, BN254.G1Point));
        if (state.operatorExists[operator]) revert OperatorAlreadyRegistered();
        state.operatorAddresses.push(operator);
        state.operatorExists[operator] = true;
        state.operatorIndex[operator] = state.allOperatorPubkeyG1.length;
        state.allOperatorPubkeyG1.push(g1Pubkey);

        verifySignature(g1Pubkey, g2Pubkey, sign, msgHash);

        // adding key bls key to aggregated keys
        state.aggregatedG1Pubkey = state.aggregatedG1Pubkey.plus(g1Pubkey);
    }

    ///@notice performs registration
    ///@param state the state in which unregistration will take place
    ///@param operator address of operator that will be unregistered
    function operatorUnregistration(State storage state, address operator) external {
        if (operator != state.operatorAddresses[state.operatorIndex[operator]]) revert OperatorAndIndexDontMatch();
        if (!state.operatorExists[operator]) revert OperatorIsNotRegistered();
        uint256 operatorAddressesLength = state.operatorAddresses.length;

        // deleting the operator pubkey
        state.allOperatorPubkeyG1[state.operatorIndex[operator]] =
            state.allOperatorPubkeyG1[state.allOperatorPubkeyG1.length - 1];
        state.allOperatorPubkeyG1.pop();

        state.operatorAddresses[state.operatorIndex[operator]] = state.operatorAddresses[operatorAddressesLength - 1];
        state.operatorIndex[state.operatorAddresses[operatorAddressesLength - 1]] = state.operatorIndex[operator];
        state.operatorAddresses.pop();

        state.operatorExists[operator] = false;
        delete state.operatorIndex[operator];

        // removing bls key from aggregated keys
        state.aggregatedG1Pubkey = state.aggregatedG1Pubkey.plus(state.operatorG1Pubkey[operator].negate());
    }

    ///@notice checks whether the paring is successful. i.e. the signature is valid
    ///@param g1Key the public key on G1 field
    ///@param g2Key the public key on G2 field 
    ///@param sign the signature on G1 field
    ///@param msgHash the message hash that has been signed
    function verifySignature(
        BN254.G1Point memory g1Key,
        BN254.G2Point memory g2Key,
        BN254.G1Point memory sign,
        bytes32 msgHash
    ) public view {
        uint256 alpha = uint256(
            keccak256(
                abi.encode(g1Key.X, g1Key.Y, g2Key.X[0], g2Key.X[1], g2Key.Y[0], g2Key.Y[1], sign.X, sign.Y, msgHash)
            )
        );
        (bool pairingSuccessful, bool signatureIsValid) = BN254.safePairing(
            sign.plus(g1Key.scalar_mul(alpha)),
            BN254.negGeneratorG2(),
            BN254.hashToG1(msgHash).plus(BN254.generatorG1().scalar_mul(alpha)),
            g2Key,
            120000
        );

        if (!pairingSuccessful) revert PairingNotSuccessful();
        if (!signatureIsValid) revert SignatureVerificationFailed();
    }

    /* ======= View Functions ======= */

    ///@notice responds with whether the operator is registered or not
    ///@param state the state in which the presence of operator will be checked
    ///@param operator address of operator whose registration status will be checked
    function isOperatorRegistered(State storage state, address operator) external view returns (bool) {
        return state.operatorExists[operator];
    }


    ///@notice returns an array of G1 public keys of all registered operators
    ///@param state the state that will be used for the retireval of G1 public keys
    function allOperatorsG1(State storage state) external view returns (BN254.G1Point[] memory) {
        BN254.G1Point[] memory operators = new BN254.G1Point[](state.allOperatorPubkeyG1.length);
        for (uint256 i = 0; i < state.allOperatorPubkeyG1.length; i++) {
            operators[i] = state.allOperatorPubkeyG1[i];
        }
        return operators;
    }

    /* ======= Errors ======= */
    error OperatorAlreadyRegistered();
    error OperatorAndIndexDontMatch();
    error OperatorIsNotRegistered();
    error SignatureVerificationFailed();
    error PairingNotSuccessful();
}

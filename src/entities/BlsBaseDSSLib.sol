// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "../interfaces/ICore.sol";
import {BN254} from "./BN254.sol";
import {ICore} from "../interfaces/ICore.sol";

library BlsBaseDSSLib {
    using BN254 for BN254.G1Point;

    struct State {
        ICore core;
        mapping(address operatorAddress => bool exists) operatorExists;
        mapping(address operatorAddress => uint256 index) operatorIndex;
        address[] operatorAddresses;
        BN254.G1Point aggregatedG1Pubkey;
        mapping(address operator => BN254.G1Point) operatorG1Pubkey;
        BN254.G1Point[] allOperatorPubkeyG1;
        bytes32 registrationMessageHash;
    }

    function addOperator(State storage state, address operator, bytes memory extraData, bytes32 msgHash) internal {
        (BN254.G1Point memory g1Pubkey, BN254.G2Point memory g2Pubkey, BN254.G1Point memory sign) =
            abi.decode(extraData, (BN254.G1Point, BN254.G2Point, BN254.G1Point));
        if (state.operatorExists[operator]) revert OperatorAlreadyRegistered();
        state.operatorG1Pubkey[operator] = g1Pubkey;
        state.operatorAddresses.push(operator);
        state.operatorExists[operator] = true;
        state.operatorIndex[operator] = state.allOperatorPubkeyG1.length;
        state.allOperatorPubkeyG1.push(g1Pubkey);

        verifySignature(g1Pubkey, g2Pubkey, sign, msgHash);

        // adding key bls key to aggregated keys
        state.aggregatedG1Pubkey = state.aggregatedG1Pubkey.plus(g1Pubkey);
    }

    function removeOperator(State storage state, address operator) internal {
        if (operator != state.operatorAddresses[state.operatorIndex[operator]]) {
            revert OperatorAndIndexDontMatch();
        }
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
        delete state.operatorG1Pubkey[operator];
    }

    function getOperators(State storage self) internal view returns (address[] memory operators) {
        operators = self.operatorAddresses;
    }

    function init(State storage self, address _core, uint256 maxSlashablePercentageWad) internal {
        self.core = ICore(_core);
        ICore(_core).registerDSS(maxSlashablePercentageWad);
    }

    function isOperatorRegistered(State storage self, address operator) internal view returns (bool) {
        return self.operatorExists[operator];
    }

    ///@notice returns an array of G1 public keys of all registered operators
    function allOperatorsG1(State storage state) internal view returns (BN254.G1Point[] memory) {
        BN254.G1Point[] memory operators = new BN254.G1Point[](state.allOperatorPubkeyG1.length);
        for (uint256 i = 0; i < state.allOperatorPubkeyG1.length; i++) {
            operators[i] = state.allOperatorPubkeyG1[i];
        }
        return operators;
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
    ) internal view {
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

    error PairingNotSuccessful();
    error OperatorIsNotRegistered();
    error OperatorAndIndexDontMatch();
    error OperatorAlreadyRegistered();
    error SignatureVerificationFailed();
}

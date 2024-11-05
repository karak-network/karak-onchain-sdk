// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import "forge-std/console.sol";
import {IBaseDSS} from "./interfaces/IBaseDSS.sol";
import {Constants} from "./interfaces/Constants.sol";
import {BN254} from "./entities/BN254.sol";
import {ICore} from "./interfaces/ICore.sol";
import {BaseDSSOperatorLib} from "./entities/BaseDSSOperatorLib.sol";
import {BlsBaseDSSLib} from "./entities/BlsBaseDSSLib.sol";
import {IStakeViewer} from "./interfaces/IStakeViewer.sol";

abstract contract BlsBaseDSS is IBaseDSS {
    using BN254 for BN254.G1Point;
    using BlsBaseDSSLib for BlsBaseDSSLib.State;
    using BaseDSSOperatorLib for BaseDSSOperatorLib.State;

    // keccak256("blsSdk.state")
    bytes32 internal constant BLS_BASE_DSS_STATE_SLOT =
        0x48bf764144336991c582aa0e94b4d726d3b4324019a2de86cdab80392c5248fc;
    bytes32 internal immutable REGISTRATION_MESSAGE_HASH;
    uint8 internal immutable THRESHOLD_PERCENTAGE;

    constructor(bytes32 registrationMessageHash, uint8 thresholdPercentage) {
        REGISTRATION_MESSAGE_HASH = registrationMessageHash;
        THRESHOLD_PERCENTAGE = thresholdPercentage;
    }

    /**
     * @notice returns the storage pointer to BLS_SDK_STATE
     * @dev can be overriden if required
     */
    function blsBaseDssStatePtr() internal view virtual returns (BlsBaseDSSLib.State storage $) {
        assembly {
            $.slot := BLS_BASE_DSS_STATE_SLOT
        }
    }

    /**
     * @notice returns the storage pointer to BASE_DSS_OPERATOR_STATE
     * @dev can be overriden if required
     */
    function baseDssOpStatePtr(address operator) internal pure virtual returns (BaseDSSOperatorLib.State storage $) {
        bytes32 slot = keccak256(abi.encode(Constants.OPERATOR_STORAGE_PREFIX, operator));
        assembly {
            $.slot := slot
        }
    }

    /* ============ External Functions ============ */

    function init(address core, uint256 maxSlashablePercentageWad) external {
        blsBaseDssStatePtr().core = ICore(core);
        blsBaseDssStatePtr().core.registerDSS(maxSlashablePercentageWad);
    }

    function kickOperator(address operator) external {
        _kickOperator(operator);
    }

    function isThresholdReached(
        IStakeViewer stakeViewer,
        address[] memory allOperators,
        address[] memory nonSigningOperators
    ) public view returns (bool) {
        uint256 allOperatorUsdStake =
            stakeViewer.getStakeDistributionUSDForOperators(address(this), allOperators, abi.encode("")).globalUsdValue;
        uint256 nonsigningOperatorUsdStake = stakeViewer.getStakeDistributionUSDForOperators(
            address(this), nonSigningOperators, abi.encode("")
        ).globalUsdValue;

        return nonsigningOperatorUsdStake >= (allOperatorUsdStake * THRESHOLD_PERCENTAGE / 100);
    }

    /* ============= Hooks ============= */

    ///@notice performs registration
    ///@param operator address of the operator that will be registered
    ///@param extraData an abi encoded bytes field that contains g1 pubkey, g2 pubkey, message hash and the signature
    function registrationHook(address operator, bytes memory extraData) external {
        blsBaseDssStatePtr().addOperator(operator, extraData, REGISTRATION_MESSAGE_HASH);
    }

    ///@notice performs registration
    ///@param operator address of operator that will be unregistered
    function unregistrationHook(address operator) external {
        blsBaseDssStatePtr().removeOperator(operator);
    }

    /**
     * @notice Called by the core when an operator initiates a request to update vault's stake in the DSS.
     * @param operator The address of the operator
     * @param newStake The vault update stake metadata
     */
    function requestUpdateStakeHook(address operator, IBaseDSS.StakeUpdateRequest memory newStake)
        public
        virtual
        onlyCore
    {
        // Removes the vault from the state if operator initiates a unstake request.
        if (!newStake.toStake) baseDssOpStatePtr(operator).removeVault(newStake.vault);
    }

    /**
     * @notice Called by the core when an operator finalizes the request to update vault's stake in the DSS.
     * @param operator The address of the operator
     * @param queuedStakeUpdate The vault queued update stake metadata
     */
    function finishUpdateStakeHook(address operator, IBaseDSS.QueuedStakeUpdate memory queuedStakeUpdate)
        public
        virtual
        onlyCore
    {
        // Adds the vault in the state only if operator finalizes to stake the vault.
        if (queuedStakeUpdate.updateRequest.toStake) {
            baseDssOpStatePtr(operator).addVault(queuedStakeUpdate.updateRequest.vault);
        }
    }

    /* ======= View Functions ======= */

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
        BlsBaseDSSLib.verifySignature(g1Key, g2Key, sign, msgHash);
    }

    ///@notice returns an array of all registered operators
    function getRegisteredOperators() external view returns (address[] memory) {
        return blsBaseDssStatePtr().getOperators();
    }

    ///@notice responds with whether the operator is registered or not
    ///@param operator address of operator whose registration status will be checked
    function isOperatorRegistered(address operator) external view returns (bool) {
        return blsBaseDssStatePtr().isOperatorRegistered(operator);
    }

    ///@notice returns an array of G1 public keys of all registered operators
    function allOperatorsG1() external view returns (BN254.G1Point[] memory) {
        return blsBaseDssStatePtr().allOperatorsG1();
    }

    /**
     * @notice checks whether operator is jailed
     * @param operator address of the operator
     */
    function isOperatorJailed(address operator) public view virtual returns (bool) {
        return baseDssOpStatePtr(operator).isOperatorJailed();
    }

    /**
     * @notice Retrieves a list of vaults not queued for withdrawal for a specific operator.
     * @param operator The address of the operator whose vaults are being fetched.
     * @return An array of vault addresses that are not queued for withdrawal.
     */
    function getActiveVaults(address operator) public view virtual returns (address[] memory) {
        return baseDssOpStatePtr(operator).fetchVaultsNotQueuedForWithdrawal();
    }

    function operatorG1(address operator) external view returns (BN254.G1Point memory) {
        return blsBaseDssStatePtr().operatorG1Pubkey[operator];
    }

    /* ============ Internal Functions ============ */

    /**
     * @notice Puts an operator in a jailed state.
     * @param operator The address of the operator to be jailed.
     */
    function _jailOperator(address operator) internal virtual {
        baseDssOpStatePtr(operator).jailOperator();
    }

    /**
     * @notice Removes an operator from a jailed state.
     * @param operator The address of the operator to be unjailed.
     */
    function _unjailOperator(address operator) internal virtual {
        baseDssOpStatePtr(operator).unjailOperator();
    }

    function _kickOperator(address operator) internal virtual {
        blsBaseDssStatePtr().removeOperator(operator);
    }

    /* ============ Modifiers ============ */
    /**
     * @dev Modifier that restricts access to only the core contract.
     * Reverts if the caller is not the core contract.
     */
    modifier onlyCore() virtual {
        if (msg.sender != address(blsBaseDssStatePtr().core)) {
            revert CallerNotCore();
        }
        _;
    }
}

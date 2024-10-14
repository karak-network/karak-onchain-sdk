// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;

import {IBaseDSS} from "./interfaces/IBaseDSS.sol";
import {BaseDSSLib} from "./entities/BaseDSSLib.sol";
import {BaseDSSOperatorLib} from "./entities/BaseDSSOperatorLib.sol";
import {Constants} from "./interfaces/Constants.sol";

abstract contract BaseDSS is IBaseDSS {
    using BaseDSSLib for BaseDSSLib.State;
    using BaseDSSOperatorLib for BaseDSSOperatorLib.State;

    // keccak256(abi.encode(uint256(keccak256("basedss.state")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal constant BASE_DSS_STATE_SLOT = 0x8814e3a199a7d4d18510abcafe7c07bd69c3920bf4c1a5d495d771ccc7597f00;

    /* ============ Mutative Functions ============ */
    /**
     * @notice operator registers through the `core` and the hook is called by the `core`
     * @param operator address of the operator
     */
    function registrationHook(address operator, bytes memory) public virtual onlyCore {
        baseDssStatePtr().addOperator(operator);
    }

    /**
     * @notice unregistration happens from the core and `unregistrationHook` is called from the core.
     * @notice Delays are already introduced in the core for staking/unstaking vaults.
     * @notice To fully unregister an operator from a DSS, it first needs to fully unstake all the vaults from that DSS.
     * @param operator address of the operator.
     */
    function unregistrationHook(address operator) public virtual onlyCore {
        baseDssStatePtr().removeOperator(operator);
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

    /* ============ View Functions ============ */

    /**
     * @notice This function returns a list of all registered operators for this DSS.
     * @return An array of addresses representing all registered operators.
     */
    function getRegisteredOperators() public view virtual returns (address[] memory) {
        return baseDssStatePtr().getOperators();
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

    /**
     * @notice Checks if the contract supports a specific interface.
     * @param interfaceId The interface ID to check.
     * @return A boolean indicating whether the interface is supported.
     */
    function supportsInterface(bytes4 interfaceId) external pure virtual returns (bool) {
        if (
            interfaceId == IBaseDSS.registrationHook.selector || interfaceId == IBaseDSS.unregistrationHook.selector
                || interfaceId == IBaseDSS.requestUpdateStakeHook.selector
                || interfaceId == IBaseDSS.finishUpdateStakeHook.selector
        ) {
            return true;
        }
        return false;
    }

    /**
     * @notice checks whether the operator is registered with dss
     * @param operator address of the operator
     */
    function isOperatorRegistered(address operator) public view virtual returns (bool) {
        return baseDssStatePtr().isOperatorRegistered(operator);
    }

    /**
     * @return address of core contract
     */
    function core() public view virtual returns (address) {
        return address(baseDssStatePtr().core);
    }

    /* ============ Internal Functions ============ */

    /**
     * @notice Initializes the BaseDSS contract by setting the core contract.
     * @notice Registers the DSS with the core using the maxSlashablePercentageWad.
     * @dev This function should be called during contract initialization not in constructor.
     * @param core The address of the core contract.
     * @param maxSlashablePercentageWad The maximum slashable percentage (in wad format) that the DSS can request.
     */
    function _init(address core, uint256 maxSlashablePercentageWad) internal virtual {
        baseDssStatePtr().init(core, maxSlashablePercentageWad);
    }

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

    /**
     * @notice returns the storage pointer to BASE_DSS_STATE
     * @dev can be overriden if required
     */
    function baseDssStatePtr() internal view virtual returns (BaseDSSLib.State storage $) {
        assembly {
            $.slot := BASE_DSS_STATE_SLOT
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

    /* ============ Modifiers ============ */
    /**
     * @dev Modifier that restricts access to only the core contract.
     * Reverts if the caller is not the core contract.
     */
    modifier onlyCore() virtual {
        if (msg.sender != address(baseDssStatePtr().core)) {
            revert CallerNotCore();
        }
        _;
    }
}

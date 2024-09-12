// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;

import {IBaseDSS} from "./interfaces/IBaseDSS.sol";
import {BaseDSSLib} from "./entities/BaseDSSLib.sol";
import {OperatorLib} from "./entities/OperatorLib.sol";

abstract contract BaseDSS is IBaseDSS {
    using BaseDSSLib for BaseDSSLib.State;
    using OperatorLib for address;

    // keccak256(abi.encode(uint256(keccak256("basedss.state")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal constant BASE_DSS_STATE_SLOT = 0x8814e3a199a7d4d18510abcafe7c07bd69c3920bf4c1a5d495d771ccc7597f00;

    /* ============ Mutative Functions ============ */
    /**
     * @notice operator registers through the `core` and the hook is called by the `core`
     * @param operator address of the operator
     */
    function registrationHook(address operator, bytes memory) external virtual onlyCore {
        _baseDssState().addOperator(operator);
    }

    /**
     * @notice unregistration happens form the protocol and `unregistrationHook` is called from the karak protocol.
     * @notice Delays are already introduced in the protocol for staking/unstaking vaults.
     * @notice To fully unregister an operator from a DSS, it first needs to fully unstake all the vaults from that DSS.
     * @dev Operator is unenrolled from all the challengers as `Challenger` had enough time to slash any operator during unstaking delay.
     * @param operator address of the operator.
     */
    function unregistrationHook(address operator) external virtual onlyCore {
        _baseDssState().removeOperator(operator);
    }

    /**
     * @notice called by the core whenever an operator calls requestUpdateVaultStakeInDSS to initiate a update vault stake request in DSS
     * @param operator The address of the operator
     * @param newStake The vault update stake metadata
     */
    function requestUpdateStakeHook(address operator, IBaseDSS.StakeUpdateRequest memory newStake)
        external
        virtual
        onlyCore
    {
        if (!newStake.toStake) operator.removeVault(newStake.vault);
    }

    /**
     * @notice called by the core whenever an operator calls finalizeUpdateVaultStakeInDSS to finalize a update vault stake request in DSS
     * @param operator The address of the operator
     * @param queuedStakeUpdate The vault queued update stake metadata
     */
    function finishUpdateStakeHook(address operator, IBaseDSS.QueuedStakeUpdate memory queuedStakeUpdate)
        external
        virtual
        onlyCore
    {
        if (queuedStakeUpdate.updateRequest.toStake) operator.addVault(queuedStakeUpdate.updateRequest.vault);
    }

    /* ============ View Functions ============ */

    /**
     * @notice This function returns a list of all registered operators for this DSS.
     * @return An array of addresses representing all registered operators.
     */
    function getRegisteredOperators() public virtual returns (address[] memory) {
        return _baseDssState().getOperators();
    }

    /**
     * @notice Retrieves a list of vaults not queued for withdrawal for a specific operator.
     * @param operator The address of the operator whose vaults are being fetched.
     * @return An array of vault addresses that are not queued for withdrawal.
     */
    function getVaultsNotQueuedForUnstaking(address operator) public virtual returns (address[] memory) {
        return operator.fetchVaultsNotQueuedForWithdrawal();
    }

    /**
     * @notice Checks if the contract supports a specific interface.
     * @param interfaceId The interface ID to check.
     * @return A boolean indicating whether the interface is supported.
     */
    function supportsInterface(bytes4 interfaceId) external pure virtual returns (bool) {
        if (interfaceId == IBaseDSS.registrationHook.selector || interfaceId == IBaseDSS.unregistrationHook.selector) {
            return true;
        }
        return false;
    }

    /* ============ Internal Functions ============ */

    /**
     * @notice Initializes the BaseDSS contract by setting the core contract and maximum slashable percentage.
     * @dev This function should be called during contract initialization or construction.
     * @param core The address of the core contract.
     * @param maxSlashablePercentageWad The maximum slashable percentage (in wad format) that the DSS can request.
     */
    function _init(address core, uint256 maxSlashablePercentageWad) internal virtual {
        _baseDssState().init(core, maxSlashablePercentageWad);
    }

    /**
     * @notice Puts an operator in a jailed state.
     * @param operator The address of the operator to be jailed.
     */
    function _jailOperator(address operator) internal virtual {
        operator.jailOperator();
    }

    /**
     * @notice Removes an operator from a jailed state.
     * @param operator The address of the operator to be unjailed.
     */
    function _unjailOperator(address operator) internal virtual {
        operator.unjailOperator();
    }

    function _baseDssState() internal pure returns (BaseDSSLib.State storage $) {
        assembly {
            $.slot := BASE_DSS_STATE_SLOT
        }
    }

    /* ============ Modifiers ============ */
    /**
     * @dev Modifier that restricts access to only the core contract.
     * Reverts if the caller is not the core contract.
     */
    modifier onlyCore() {
        if (msg.sender != address(_baseDssState().core)) {
            revert CallerNotCore();
        }
        _;
    }
}

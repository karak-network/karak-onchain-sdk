// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;

import "./interfaces/IStakeViewer.sol";
import "./interfaces/IDSS.sol";
import "./entities/BaseDSSLib.sol";

abstract contract BaseDSS is IDSS {
    using BaseDSSLib for BaseDSSLib.State;

    // keccak256(abi.encode(uint256(keccak256("basedss.state")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal constant BASEDSS_STATE_SLOT = 0x8814e3a199a7d4d18510abcafe7c07bd69c3920bf4c1a5d495d771ccc7597f00;

    /* ============ Mutative Functions ============ */
    /**
     * @notice operator registers through the `core` and the hook is called by the `core`
     * @param operator address of the operator
     */
    function registrationHook(address operator, bytes memory) external virtual onlyCore {
        _self().updateOperatorMap(operator, true);
    }

    /**
     * @notice unregistration happens form the protocol and `unregistrationHook` is called from the karak protocol.
     * Delays are already introduced in the protcol for staking/unstaking vaults. To unregister operator needs to fully unstake.
     * @dev Operator is unenrolled from all the challengers as `Challenger` had enough time to slash any operator during unstaking delay.
     * @param operator address of the operator.
     */
    function unregistrationHook(address operator) external virtual onlyCore {
        _self().updateOperatorMap(operator, false);
    }

    /* ============ View Functions ============ */

    function getRegisteredOperators() public virtual returns (address[] memory) {
        return _self().getOperators();
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        if (interfaceId == IDSS.registrationHook.selector || interfaceId == IDSS.unregistrationHook.selector) {
            return true;
        }
        return false;
    }

    /* ============ Internal Functions ============ */
    function _init(address core) internal {
        _self().init(core);
    }

    function _self() internal pure returns (BaseDSSLib.State storage $) {
        assembly {
            $.slot := BASEDSS_STATE_SLOT
        }
    }

    /* ============ Modifiers ============ */
    modifier onlyCore() {
        if (msg.sender != _self().core) {
            revert CallerNotCore();
        }
        _;
    }
}

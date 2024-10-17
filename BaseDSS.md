# BaseDSS

## Overview

`BaseDSS` is an abstract contract that provides a base implementation for a DSS. It includes the hooks which are called from the core contract whenever an operator interacts with core to register/unregister with the DSS or stake/unstake vaults from the DSS.

## Table of Contents

1. [Contract Structure](#contract-structure)
2. [Usage Example](#usage-example)
2. [Functionality Overview](#functionality-overview)
   - [Mutative Functions](#mutative-functions)
   - [View Functions](#view-functions)
   - [Internal Functions](#internal-functions)
   - [Modifiers](#modifiers)
---

## Contract Structure

The `BaseDSS` contract uses Namespaced Storage Layout for storing the states:

- **Structs**:
  - `BaseDSSLib`: Stores and manages state at DSS level (i.e. storing core addresses and maintaining operator set).
  - `BaseDSSOperatorLib`: Stores and manages state at operator level (i.e. vault management and jailing status).

## Usage Example

To implement `BaseDSS` in a derived contract, ensure the following steps:

```solidity

import {BaseDSS} from "./BaseDSS.sol";

contract SampleDSS is BaseDSS {
```
1. **Initialize the DSS**: 
   -  Call `_init()` with the core contract address and the desired maximum slashable percentage.
   -  Sets the core address and registers the DSS with the core.
   -  **Should not be called from the constructor as the core expects the caller to be a smart contract(i.e address with code_size > 0).**
   ```solidity
   function initializeDSS(address core, uint256 maxSlashablePercentageWad) external {
        // Calls the internal _init function from BaseDSS
        _init(core, maxSlashablePercentageWad);
        emit DSSInitialized(core, maxSlashablePercentageWad);
   }
   ```
   
2. **Optional Overloading:**
   1. **Registration/UnregistrationHook**
      ```solidity
         function registrationHook(address operator, bytes memory data) public override onlyCore {
            super.registrationHook(operator, data);  // Calls the BaseDSS hook logic
            // Add any custom logic here
         }

         function unregistrationHook(address operator) public override onlyCore {
            super.unregistrationHook(operator);  // Calls the BaseDSS hook logic
            // Add any custom logic here
         }
      ```

   2. **RequestUpdateStakeHook/FinishUpdateStakeHook**
   ```solidity
      function requestUpdateStakeHook(address operator, IBaseDSS.StakeUpdateRequest memory newStake)
            public
            override
            onlyCore
         {
            super.requestUpdateStakeHook(operator, newStake);  // Calls the BaseDSS hook logic
            // Add any custom logic here
         }

         function finishUpdateStakeHook(address operator, IBaseDSS.QueuedStakeUpdate memory queuedStakeUpdate)
            public
            override
            onlyCore
         {
            super.finishUpdateStakeHook(operator, queuedStakeUpdate);  // Calls the BaseDSS hook logic
            // Add any custom logic here
         }
   ```
   3. **Jailing/Unjailing**
   ```solidity
      function jailOperator(address operator) external {
         _jailOperator(operator);  // Uses internal function to jail the operator
      }

      function unjailOperator(address operator) external {
         _unjailOperator(operator);  // Uses internal function to unjail the operator
      }
   }
   ```
   4. **Using custom pointer for BaseDSSPtr and BaseDSSOpStatePtr**
   ```solidity
   function baseDssStatePtr() internal view override returns (BaseDSSLib.State storage $) {
        // return the pointer to the BaseDSSLib.State storage variable.
    }

    function baseDssOpStatePtr(address operator) internal pure override returns (BaseDSSOperatorLib.State storage $) {
        // return the pointer to the BaseDSSOperatorLib.State storage variable.
    }
   ```


## Functionality Overview

1. **`registrationHook(address operator, bytes memory)`**
   - **Description**: The core contract calls this hook whenever an operator registers with the DSS. This adds the operator in the operatorSet.
   - **Parameters**:
     - `operator`: Address of the operator to be registered.
   - **Modifiers**: `onlyCore`

2. **`unregistrationHook(address operator)`**
   - **Description**: The core contract calls this hook, after an operator successfully unregisters from the DSS. This removes the operator from the operatorSet.
   - **Parameters**:
     - `operator`: Address of the operator to be unregistered.
   - **Modifiers**: `onlyCore`

3. **`requestUpdateStakeHook(address operator, IBaseDSS.StakeUpdateRequest memory newStake)`**
   - **Description**: Called by the core when an operator requests to update their vault stake. Removes the vault from the set of active vaults when unstaking is requested.
   - **Parameters**:
     - `operator`: Address of the operator.
     - `newStake`: A structure containing the stake update request data.
   - **Modifiers**: `onlyCore`

4. **`finishUpdateStakeHook(address operator, IBaseDSS.QueuedStakeUpdate memory queuedStakeUpdate)`**
   - **Description**: Called by the core when an operator finalizes their vault stake update request. Adds the vault to the set of active vaults when staking is finalized.
   - **Parameters**:
     - `operator`: Address of the operator.
     - `queuedStakeUpdate`: A structure containing the queued stake update information.
   - **Modifiers**: `onlyCore`

### View Functions

1. **`getRegisteredOperators()`**
   - **Description**: Returns a list of all currently registered operators in the DSS.
   - **Returns**: An array of operator addresses.

2. **`isOperatorJailed(address operator)`**
   - **Description**: Checks if an operator is currently jailed.
   - **Parameters**:
     - `operator`: The address of the operator to check.
   - **Returns**: Boolean indicating if the operator is jailed.

3. **`getActiveVaults(address operator)`**
   - **Description**: Retrieves the list of active vaults (not queued for withdrawal) associated with a specific operator.
   - **Parameters**:
     - `operator`: Address of the operator.
   - **Returns**: An array of vault addresses.

4. **`supportsInterface(bytes4 interfaceId)`**
   - **Description**:
      - Checks if the contract supports a specific function.
      - Core contract calls the hook only if the above check is passed.
   - **Parameters**:
     - `interfaceId`: The identifier of the function to check.
   - **Returns**: Boolean indicating support for the function.

5. **`isOperatorRegistered(address operator)`**
   - **Description**: Checks if an operator is currently registered with the DSS.
   - **Parameters**:
     - `operator`: Address of the operator.
   - **Returns**: Boolean indicating if the operator is registered.

6. **`core()`**
   - **Description**: Returns the address of the core contract managing the DSS.
   - **Returns**: Address of the core contract.

### Internal Functions

1. **`_init(address core, uint256 maxSlashablePercentageWad)`**
   - **Description**: Initializes the `BaseDSS` contract, setting the core contract and registering the DSS with the maximum slashable percentage.
   - **Parameters**:
     - `core`: Address of the core contract.
     - `maxSlashablePercentageWad`: Maximum slashable percentage in WAD format.
   - **Usage**: Should be called during contract initialization, not in the constructor.

2. **`_jailOperator(address operator)`**
   - **Description**: Marks an operator as jailed.
   - **Parameters**:
     - `operator`: Address of the operator to jail.

3. **`_unjailOperator(address operator)`**
   - **Description**: Removes the jailed status from an operator.
   - **Parameters**:
     - `operator`: Address of the operator to unjail.

4. **`baseDssStatePtr()`**
   - **Description**: Returns the storage pointer to the `BaseDSSLib.State`.
   - **Usage**: Can be overridden if necessary.

5. **`baseDssOpStatePtr(address operator)`**
   - **Description**: Returns the storage pointer to the `BaseDSSOperatorLib.State` for a specific operator.
   - **Usage**: Can be overridden if necessary.

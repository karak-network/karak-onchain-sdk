// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

library CommonUtils {
    /// Sorts the array using quick sort inplace
    /// @param arr Array to sort
    function sortArr(address[] memory arr) private pure {
        if (arr.length == 0) return;
        sort(arr, 0, arr.length - 1);
    }

    function sort(address[] memory arr, uint256 left, uint256 right) private pure {
        if (left >= right) return;
        uint256 lastUnsortedInd = left;
        uint256 pivot = right;
        for (uint256 i = left; i < right; i++) {
            if (arr[i] <= arr[pivot]) {
                if (i != lastUnsortedInd) swap(arr, i, lastUnsortedInd);
                lastUnsortedInd++;
            }
        }
        swap(arr, pivot, lastUnsortedInd);
        if (lastUnsortedInd > left) {
            sort(arr, left, lastUnsortedInd - 1);
        }
        sort(arr, lastUnsortedInd, right);
    }

    function swap(address[] memory arr, uint256 left, uint256 right) private pure {
        address temp = arr[left];
        arr[left] = arr[right];
        arr[right] = temp;
    }

    function assertEq(address[] memory arr1, address[] memory arr2) public pure {
        sortArr(arr1);
        sortArr(arr2);
        if (keccak256(abi.encode((arr1))) != keccak256(abi.encode(arr2))) revert UnequalArrays();
    }

    error UnequalArrays();
}

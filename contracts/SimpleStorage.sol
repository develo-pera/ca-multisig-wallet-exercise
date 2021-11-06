// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

contract SimpleStorage {
    uint public storedData;

    address public caller;

    function set(uint x) public {
        caller = msg.sender;
        storedData = x;
    }
}

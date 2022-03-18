// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface IMobsterLevelList {
    function getMobsterLevel(
        uint32 mobsterIndex
    ) external view returns (uint8 level);
}
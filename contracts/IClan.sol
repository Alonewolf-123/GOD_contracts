// SPDX-License-Identifier: MIT LICENSE 

pragma solidity ^0.8.0;

interface IClan {
  function addManyToClan(uint32[] calldata tokenIds) external;
}
// SPDX-License-Identifier: MIT LICENSE 

pragma solidity ^0.8.0;

interface IClan {
  function addManyToClanAndPack(address account, uint16[] calldata tokenIds) external;
  function randomMobsterOwner(uint256 seed) external view returns (address);
}
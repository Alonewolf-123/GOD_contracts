// SPDX-License-Identifier: MIT LICENSE 

pragma solidity ^0.8.0;

interface IClan {
  function addManyToClan(address account, uint16[] calldata tokenIds, uint8 cityId) external;
  function randomMobsterOwner(uint256 seed) external view returns (address);
  function getMaxNumCity() external view returns (uint8);
  function getAvailableCity() external view returns (uint8);
  function getNumMobstersByCityId(uint8 cityId) external view returns (uint16[] memory);
}
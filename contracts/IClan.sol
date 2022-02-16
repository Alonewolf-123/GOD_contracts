// SPDX-License-Identifier: MIT LICENSE 

pragma solidity ^0.8.0;

interface IClan {
  function addManyToClan(uint32[] calldata tokenIds) external;
  function randomMobsterOwner(uint256 seed) external view returns (address);
  function getMaxNumCityOfGen() external view returns (uint8[] memory);
  function getAvailableCity() external view returns (uint8);
  function getNumMobstersOfCity(uint8 cityId) external view returns (uint16[] memory);
}
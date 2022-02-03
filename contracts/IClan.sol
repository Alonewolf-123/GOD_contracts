// SPDX-License-Identifier: MIT LICENSE 

pragma solidity ^0.8.0;

interface IClan {
  function addManyToClanAndPack(address account, uint16[] calldata tokenIds) external;
  function randomMobsterOwner(uint256 seed) external view returns (address);
  function getAvailableCity() external view returns (uint8);
  function getNumDwarfather(uint8 cityId) external view returns (uint16);
  function getNumBoss(uint8 cityId) external view returns (uint16);
  function getNumDwarfCapos(uint8 cityId) external view returns (uint16);
  function getNumDwarfSoldier(uint8 cityId) external view returns (uint16);
}
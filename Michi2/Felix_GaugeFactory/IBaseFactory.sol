/**
 * @title Interface Base V1 Factory
 * @dev IBaseV1Factory.sol contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

pragma solidity =0.8.11;

interface IBaseV1Factory {
    function isPair(address _tokenLP) external returns (bool);
}

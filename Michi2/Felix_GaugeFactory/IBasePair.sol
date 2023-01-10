/**
 * @title Interface Base V1 Pair
 * @dev IBaseV1Pair.sol contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

pragma solidity =0.8.11;

interface IBaseV1Pair {
    function claimFees() external returns (uint256, uint256);

    function tokens() external returns (address, address);

    function stable() external returns (bool);
}

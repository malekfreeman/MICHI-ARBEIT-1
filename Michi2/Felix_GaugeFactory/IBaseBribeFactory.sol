/**
 * @title Interface Base V1 Bribe Factory
 * @dev IBaseV1BribeFactory.sol contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

pragma solidity =0.8.11;

interface IBaseV1BribeFactory {
    function createBribe(
        address owner,
        address _token0,
        address _token1
    ) external returns (address);
}

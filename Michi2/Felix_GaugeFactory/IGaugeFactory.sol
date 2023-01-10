/**
 * @title Interface Gauge Factory
 * @dev IGaugeFactory.sol contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

pragma solidity =0.8.11;

interface IGaugeFactory {
    function bribes(address gauge) external returns (address);

    function baseReferralsContract() external returns (address);

    function baseReferralFee() external returns (uint256);

    function governance() external returns (address);

    function admin() external returns (address);

    function mainRefFeeReceiver() external returns (address);

    function weights(address _token) external view returns (uint256);

    function votes(address _user, address _token)
        external
        view
        returns (uint256);

    function poke(address _owner) external;

    function nextPoke(address _owner) external returns (uint256);
}

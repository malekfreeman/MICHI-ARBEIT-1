/**
 * @title Interface Referrals
 * @dev IReferrals contract
 *
 * @author - <MIDGARD TRUST>
 * for the Midgard Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

pragma solidity 0.6.12;

interface IReferrals {
    function getSponsor(address account) external view returns (address);
}
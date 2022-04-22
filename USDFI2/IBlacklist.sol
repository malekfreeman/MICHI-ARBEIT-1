/**
 * @title Interface Blacklist
 * @dev IBlacklist contract
 *
 * @author - <MIDGARD TRUST>
 * for the Midgard Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

pragma solidity 0.6.12;

interface IBlacklist {
    function isBlacklisted(address _address) external view returns (bool);
}

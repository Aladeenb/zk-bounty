// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBounties {
    // -------
    // Structs
    // -------

    enum BountyType { ApiKey }

    // Data structure for a bounty
    struct Bounty {
        address submitter;
        BountyType bountyType;
        uint256 reward;
        bytes32 bountyHash;
    }

    // Map for storing bounties
    struct BountyMap {
        mapping(bytes16 => Bounty) values;
        bytes16[] keys;
    }

    // Functions for Bounty operations
    function get(bytes16 key) external view returns (Bounty memory);
    function getKeyAtIndex(uint256 index) external view returns (bytes16);
    function size() external view returns (uint256);
    function set(bytes16 key, Bounty memory val) external;
    function remove(bytes16 key) external;
}
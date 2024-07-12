// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IBounties.sol";
import "./IReports.sol";

contract ZKBounty is IBounties, IReports {

    // Global storage holding bounties and reports
    BountyMap private bountiesMap;  // Internal BountyMap structure for managing bounties
    mapping(bytes16 => Report) public reports;

    // ------
    // Events
    // ------
    event BountySubmitted(bytes16 indexed bountyId, address indexed submitter, BountyType bountyType, uint256 reward);
    event ReportSubmitted(bytes16 indexed bountyId, address indexed worker);
    event ReportApproved(bytes16 indexed bountyId);
    
    // ---------
    // Modifiers
    // ---------
    // Only the submitter can approve the report
    modifier onlySubmitter(bytes16 _bountyId) {
        require(msg.sender == bountiesMap.values[_bountyId].submitter, "Not the submitter");
        _;
    }

    // ----------------
    // Assert Functions
    // ----------------
    // Assert that the bounty exists given a bountyId
    function assertBountyExists(bytes16 _bountyId) internal view {
        require(bountiesMap.values[_bountyId].reward > 0, "Bounty does not exist");
    }

    // Assert that the report exists given a bountyId
    function assertReportExists(bytes16 _bountyId) internal view {
        require(reports[_bountyId].isSubmitted, "Report does not exist");
    }

    // ---------------
    // Write Functions
    // ---------------

    // Submit a new bounty
    function submitBounty(BountyType _bountyType, uint256 _reward, bytes32 _bountyHash) external returns (bytes16) {
        // Generate a unique bountyId
        bytes16 uuid = generateUUID();
        // Create a new bounty
        Bounty memory newBounty = Bounty({
            submitter: msg.sender,
            bountyType: _bountyType,
            reward: _reward,
            bountyHash: _bountyHash
        });

        // Add bounty to the map
        bountiesMap.values[uuid] = newBounty;
        bountiesMap.keys.push(uuid);
        
        emit BountySubmitted(uuid, msg.sender, _bountyType, _reward);

        return uuid;
    }
    
    // Submit a report for a bounty
    function submitReport(bytes16 _bountyId, bytes32 _reportHash) external {
        assertBountyExists(_bountyId);
        
        reports[_bountyId] = Report({
            worker: msg.sender,
            reportHash: _reportHash,
            isSubmitted: true
        });
        
        emit ReportSubmitted(_bountyId, msg.sender);
    }

    // Approves a report and transfers the reward to the worker
    function approveReport(bytes16 _bountyId) external onlySubmitter(_bountyId) {
        assertBountyExists(_bountyId);
        assertReportExists(_bountyId);

        Bounty memory bounty = bountiesMap.values[_bountyId];
        Report memory report = reports[_bountyId];
        
        payable(report.worker).transfer(bounty.reward);

        // Delete the bounty and report at the given bountyId
        delete bountiesMap.values[_bountyId];
        for (uint i = 0; i < bountiesMap.keys.length; i++) {
            if (bountiesMap.keys[i] == _bountyId) {
                bountiesMap.keys[i] = bountiesMap.keys[bountiesMap.keys.length - 1];
                bountiesMap.keys.pop();
                break;
            }
        }
        delete reports[_bountyId];
        
        emit ReportApproved(_bountyId);
    }
    
    // Deposits Ether into the contract for rewards
    function depositReward() external payable {
        require(msg.value > 0, "Must send Ether to deposit reward");
    }
    
    // Withdraws unapproved bounties by the submitter
    function withdrawUnapprovedBounty(bytes16 _bountyId) external onlySubmitter(_bountyId) {
        assertBountyExists(_bountyId);
        Bounty memory bounty = bountiesMap.values[_bountyId];
        uint256 reward = bounty.reward;
        // Ensure the reward is zeroed out to prevent re-entrancy attacks
        bountiesMap.values[_bountyId].reward = 0;
        payable(msg.sender).transfer(reward);
    }

    // Generates a pseudo-random UUID-like identifier
    function generateUUID() public view returns (bytes16) {
        return bytes16(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            msg.sender,
            bountiesMap.keys.length  // Include some unique element
        )));
    }

    // --------------
    // Read Functions
    // --------------

    function getBountyType() external pure returns (BountyType) {
        return BountyType.ApiKey;  // Define the bountyType here, assuming a single type for simplicity
    }
    
    // Checks if a bounty exists given a bountyId
    function bountyExists(bytes16 _bountyId) external view returns (bool) {
        return bountiesMap.values[_bountyId].submitter != address(0);
    }

    // Checks if a report exists given a bountyId
    function reportExists(bytes16 _bountyId) external view returns (bool) {
        return reports[_bountyId].isSubmitted;
    }

    // Functions to interface with BountyMap
    function get(bytes16 _bountyId) external view override returns (Bounty memory) {
        return bountiesMap.values[_bountyId];
    }

    function getKeyAtIndex(uint256 index) external view override returns (bytes16) {
        return bountiesMap.keys[index];
    }

    function size() external view override returns (uint256) {
        return bountiesMap.keys.length;
    }

    function set(bytes16 _bountyId, Bounty memory _bounty) external override {
        bountiesMap.values[_bountyId] = _bounty;
        bool found = false;
        for (uint i = 0; i < bountiesMap.keys.length; i++) {
            if (bountiesMap.keys[i] == _bountyId) {
                found = true;
                break;
            }
        }
        if (!found) {
            bountiesMap.keys.push(_bountyId);
        }
    }

    function remove(bytes16 _bountyId) external override {
        delete bountiesMap.values[_bountyId];
        for (uint i = 0; i < bountiesMap.keys.length; i++) {
            if (bountiesMap.keys[i] == _bountyId) {
                bountiesMap.keys[i] = bountiesMap.keys[bountiesMap.keys.length - 1];
                bountiesMap.keys.pop();
                break;
            }
        }
    }

    // Fallback function to accept Ether
    receive() external payable {}
}
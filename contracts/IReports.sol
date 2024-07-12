// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IReports {
    // Struct for a report
    struct Report {
        address worker;
        bytes32 reportHash;
        bool isSubmitted;
    }
}

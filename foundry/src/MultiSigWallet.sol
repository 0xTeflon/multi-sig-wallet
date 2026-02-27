// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

contract MultiSigWallet {
    // State variables
    address[3] public signers;
    mapping(address => bool) public isSigner;
    mapping(uint256 => mapping(address => bool)) public approvals;
    uint256 public threshold = 2;
    uint256 public transactionCount;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
    }

    mapping(uint256 => Transaction) public transactions;

    // Events
    event TransactionSubmitted(uint256 indexed txId, address indexed submitter, address to, uint256 value);
    event TransactionApproved(uint256 indexed txId, address indexed approver);
    event TransactionExecuted(uint256 indexed txId);

    modifier onlySigner() {
        require(isSigner[msg.sender], "Not a signer");
        _;
    }
    constructor(address signer1, address signer2, address signer3) {
        signers[0] = signer1;
        signers[1] = signer2;
        signers[2] = signer3;

        isSigner[signer1] = true;
        isSigner[signer2] = true;
        isSigner[signer3] = true;
    }

    receive() external payable {}

    function submitTransaction(address to, uint256 value, bytes calldata data) external onlySigner returns (uint256) {
        uint256 txId = transactionCount;
        transactions[txId] = Transaction(to, value, data, false);
        transactionCount++;

        emit TransactionSubmitted(txId, msg.sender, to, value);
        return txId;
    }
    function approveTransaction(uint256 txId) external onlySigner {
        require(txId < transactionCount, "Invalid transaction");
        require(!transactions[txId].executed, "Transaction already executed");
        require(!approvals[txId][msg.sender], "Already approved");

        approvals[txId][msg.sender] = true;
        emit TransactionApproved(txId, msg.sender);
    }

    function getApprovalCount(uint256 txId) public view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < 3; i++) {
            if (approvals[txId][signers[i]]) {
                count++;
            }
        }
        return count;
    }

    function executeTransaction(uint256 txId) external {
        require(txId < transactionCount, "Invalid transaction");
        require(!transactions[txId].executed, "Transaction already executed");
        require(getApprovalCount(txId) >= threshold, "Not enough approvals");

        Transaction storage txn = transactions[txId];
        txn.executed = true;

        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Transaction failed");

        emit TransactionExecuted(txId);
    }
}
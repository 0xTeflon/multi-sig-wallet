// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/MultiSigWallet.sol";

contract Receiver {
    uint256 public received;
    event GotPaid(address from, uint256 amount);

    receive() external payable {
        received += msg.value;
        emit GotPaid(msg.sender, msg.value);
    }
}

contract MultiSigWalletTest is Test {
    MultiSigWallet wallet;

    address signer1 = address(0xA1);
    address signer2 = address(0xA2);
    address signer3 = address(0xA3);
    address notSigner = address(0xB0);

    Receiver receiver;

    function setUp() public {
        wallet = new MultiSigWallet(signer1, signer2, signer3);
        receiver = new Receiver();

        vm.deal(address(wallet), 10 ether);
        vm.deal(signer1, 1 ether);
        vm.deal(signer2, 1 ether);
        vm.deal(signer3, 1 ether);
        vm.deal(notSigner, 1 ether);
    }

    function test_constructorSetsSigners() public {
        assertEq(wallet.signers(0), signer1);
        assertEq(wallet.signers(1), signer2);
        assertEq(wallet.signers(2), signer3);

        assertTrue(wallet.isSigner(signer1));
        assertTrue(wallet.isSigner(signer2));
        assertTrue(wallet.isSigner(signer3));

        assertEq(wallet.threshold(), 2);
    }

    function test_submitTransaction_onlySigner() public {
        vm.prank(notSigner);
        vm.expectRevert("Not a signer");
        wallet.submitTransaction(address(receiver), 1 ether, "");
    }

    function test_submitTransaction_storesTxAndIncrementsCount() public {
        vm.prank(signer1);
        uint256 txId = wallet.submitTransaction(address(receiver), 1 ether, "");

        assertEq(txId, 0);
        assertEq(wallet.transactionCount(), 1);

        (address to, uint256 value, bytes memory data, bool executed) = wallet.transactions(txId);

        assertEq(to, address(receiver));
        assertEq(value, 1 ether);
        assertEq(data, bytes(""));
        assertEq(executed, false);
    }

    function test_approveTransaction_onlySigner() public {
        vm.prank(signer1);
        uint256 txId = wallet.submitTransaction(address(receiver), 1 ether, "");

        vm.prank(notSigner);
        vm.expectRevert("Not a signer");
        wallet.approveTransaction(txId);
    }

    function test_approveTransaction_cannotApproveTwice() public {
        vm.prank(signer1);
        uint256 txId = wallet.submitTransaction(address(receiver), 1 ether, "");

        vm.prank(signer2);
        wallet.approveTransaction(txId);

        vm.prank(signer2);
        vm.expectRevert("Already approved");
        wallet.approveTransaction(txId);
    }

    function test_executeTransaction_failsWithoutEnoughApprovals() public {
        vm.prank(signer1);
        uint256 txId = wallet.submitTransaction(address(receiver), 1 ether, "");

        vm.prank(signer1);
        wallet.approveTransaction(txId);

        vm.expectRevert("Not enough approvals");
        wallet.executeTransaction(txId);
    }

    function test_executeTransaction_succeedsWithTwoApprovals_andSendsETH() public {
        vm.prank(signer1);
        uint256 txId = wallet.submitTransaction(address(receiver), 1 ether, "");

        vm.prank(signer1);
        wallet.approveTransaction(txId);

        vm.prank(signer2);
        wallet.approveTransaction(txId);

        uint256 receiverBalBefore = address(receiver).balance;

        wallet.executeTransaction(txId);

        uint256 receiverBalAfter = address(receiver).balance;
        assertEq(receiverBalAfter, receiverBalBefore + 1 ether);

        (, , , bool executed) = wallet.transactions(txId);
        assertTrue(executed);
    }

    function test_executeTransaction_cannotExecuteTwice() public {
        vm.prank(signer1);
        uint256 txId = wallet.submitTransaction(address(receiver), 1 ether, "");

        vm.prank(signer1);
        wallet.approveTransaction(txId);

        vm.prank(signer2);
        wallet.approveTransaction(txId);

        wallet.executeTransaction(txId);

        vm.expectRevert("Transaction already executed");
        wallet.executeTransaction(txId);
    }

    function test_executeTransaction_invalidTxId() public {
        vm.expectRevert("Invalid transaction");
        wallet.executeTransaction(999);
    }
}
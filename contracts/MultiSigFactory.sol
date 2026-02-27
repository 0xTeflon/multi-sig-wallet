// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./MultiSigWallet.sol";

contract MultiSigFactory {

    address[] public allWallets;

    mapping(address => address[]) public walletsByCreator;

    event WalletCreated(
        address indexed creator,
        address indexed wallet,
        address signer1,
        address signer2,
        address signer3
    );

    function createWallet(
        address signer1,
        address signer2,
        address signer3
    ) external returns (address) {

        require(signer1 != address(0), "zero address");
        require(signer2 != address(0), "zero address");
        require(signer3 != address(0), "zero address");

        require(
            signer1 != signer2 &&
            signer1 != signer3 &&
            signer2 != signer3,
            "duplicate signer"
        );

        MultiSigWallet wallet = new MultiSigWallet(
            signer1,
            signer2,
            signer3
        );

        address walletAddress = address(wallet);

        allWallets.push(walletAddress);
        walletsByCreator[msg.sender].push(walletAddress);

        emit WalletCreated(
            msg.sender,
            walletAddress,
            signer1,
            signer2,
            signer3
        );

        return walletAddress;
    }

    function getAllWallets() external view returns (address[] memory) {
        return allWallets;
    }

    function getMyWallets() external view returns (address[] memory) {
        return walletsByCreator[msg.sender];
    }
}
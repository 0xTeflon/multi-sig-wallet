// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract MultiSigWalletScript is Script {
    MultiSigWallet public wallet;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // deploy with dummy signers for demonstration
        wallet = new MultiSigWallet(address(0xA1), address(0xA2), address(0xA3));

        vm.stopBroadcast();
    }
}

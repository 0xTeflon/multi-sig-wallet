import { expect } from "chai";
import hre from "hardhat";

describe("MultiSigWallet", function () {
  async function deployMultiSigWalletFixture() {
    const [signer1, signer2, signer3, other] = await hre.ethers.getSigners();

    const MultiSigWallet = await hre.ethers.getContractFactory(
      "MultiSigWallet",
    );
    const wallet = await MultiSigWallet.deploy(
      signer1.address,
      signer2.address,
      signer3.address,
    );

    // Send 10 ETH to the wallet
    await signer1.sendTransaction({
      to: await wallet.getAddress(),
      value: hre.ethers.parseEther("10"),
    });

    return { wallet, signer1, signer2, signer3, other };
  }

  describe("Deployment", function () {
    it("Should set the correct signers", async function () {
      const { wallet, signer1, signer2, signer3 } =
        await deployMultiSigWalletFixture();

      expect(await wallet.signers(0)).to.equal(signer1.address);
      expect(await wallet.signers(1)).to.equal(signer2.address);
      expect(await wallet.signers(2)).to.equal(signer3.address);
    });

    it("Should have threshold of 2", async function () {
      const { wallet } = await deployMultiSigWalletFixture();
      expect(await wallet.threshold()).to.equal(2);
    });

    it("Should receive ether", async function () {
      const { wallet } = await deployMultiSigWalletFixture();
      const balance = await hre.ethers.provider.getBalance(
        await wallet.getAddress(),
      );
      expect(balance).to.equal(hre.ethers.parseEther("10"));
    });
  });

  describe("Transaction Flow", function () {
    it("Should submit a transaction", async function () {
      const { wallet, signer1, other } = await deployMultiSigWalletFixture();

      const tx = await wallet
        .connect(signer1)
        .submitTransaction(other.address, hre.ethers.parseEther("1"), "0x");

      expect(tx).to.emit(wallet, "TransactionSubmitted");
      expect(await wallet.transactionCount()).to.equal(1);
    });

    it("Should not allow non-signers to submit", async function () {
      const { wallet, other } = await deployMultiSigWalletFixture();

      await expect(
        wallet
          .connect(other)
          .submitTransaction(other.address, hre.ethers.parseEther("1"), "0x"),
      ).to.be.revertedWith("Not a signer");
    });

    it("Should approve a transaction", async function () {
      const { wallet, signer1, signer2, other } =
        await deployMultiSigWalletFixture();

      // Submit transaction
      await wallet
        .connect(signer1)
        .submitTransaction(other.address, hre.ethers.parseEther("1"), "0x");

      // Approve transaction
      await wallet.connect(signer2).approveTransaction(0);
      expect(await wallet.approvals(0, signer2.address)).to.be.true;
    });

    it("Should execute transaction with 2 approvals", async function () {
      const { wallet, signer1, signer2, other } =
        await deployMultiSigWalletFixture();

      const initialBalance = await hre.ethers.provider.getBalance(
        other.address,
      );

      // Submit transaction
      await wallet
        .connect(signer1)
        .submitTransaction(other.address, hre.ethers.parseEther("1"), "0x");

      // Get approvals from signer1 and signer2
      await wallet.connect(signer1).approveTransaction(0);
      await wallet.connect(signer2).approveTransaction(0);

      // Execute transaction
      await wallet.executeTransaction(0);

      const finalBalance = await hre.ethers.provider.getBalance(other.address);
      expect(finalBalance - initialBalance).to.equal(
        hre.ethers.parseEther("1"),
      );
    });

    it("Should not execute with only 1 approval", async function () {
      const { wallet, signer1, other } = await deployMultiSigWalletFixture();

      // Submit transaction
      await wallet
        .connect(signer1)
        .submitTransaction(other.address, hre.ethers.parseEther("1"), "0x");

      // Only 1 approval
      await wallet.connect(signer1).approveTransaction(0);

      // Should fail
      await expect(wallet.executeTransaction(0)).to.be.revertedWith(
        "Not enough approvals",
      );
    });
  });
});

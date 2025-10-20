import { describe, it, beforeEach } from "node:test";
import { expect } from "chai";
import { network } from "hardhat";
import { parseEther } from "viem";

describe("WrapperToken ERC20Wrapper Implementation", () => {
  let accounts: any;
  let mockERC20: any;
  let wrapperToken: any;
  let vault: any;

  beforeEach(async () => {
    const { viem } = await network.connect();
    accounts = await viem.getWalletClients();
    
    // Deploy mock ERC20 token
    mockERC20 = await viem.deployContract("MockERC20", [
      "Mock Token",
      "MOCK",
      parseEther("1000000")
    ]);

    // Deploy WrapperToken with ERC20Wrapper
    wrapperToken = await viem.deployContract("WrapperToken", [
      mockERC20.address,
      "Wrapped Mock",
      "xMOCK"
    ]);

    // Deploy mock vault for testing
    vault = await viem.deployContract("MockVault", []);
    
    // Authorize vault
    await wrapperToken.write.authorizeVault([vault.address]);
  });

  it("should wrap tokens using ERC20Wrapper depositFor", async () => {
    const amount = parseEther("100");
    
    // Approve and deposit
    await mockERC20.write.approve([wrapperToken.address, amount]);
    await wrapperToken.write.depositFor([accounts[0].account.address, amount]);
    
    // Check balances
    const wrapperBalance = await wrapperToken.read.balanceOf([accounts[0].account.address]);
    const underlyingBalance = await mockERC20.read.balanceOf([wrapperToken.address]);
    
    expect(wrapperBalance).to.equal(amount);
    expect(underlyingBalance).to.equal(amount);
  });

  it("should wrap tokens using legacy wrap function", async () => {
    const amount = parseEther("100");
    
    // Approve and wrap
    await mockERC20.write.approve([wrapperToken.address, amount]);
    await wrapperToken.write.wrap([amount]);
    
    // Check balances
    const wrapperBalance = await wrapperToken.read.balanceOf([accounts[0].account.address]);
    expect(wrapperBalance).to.equal(amount);
  });

  it("should prevent unwrap of locked tokens", async () => {
    const amount = parseEther("100");
    const lockAmount = parseEther("30");
    
    // Wrap tokens
    await mockERC20.write.approve([wrapperToken.address, amount]);
    await wrapperToken.write.wrap([amount]);
    
    // Lock some tokens via vault
    await wrapperToken.write.lockTokens([accounts[0].account.address, lockAmount], {
      account: vault.account
    });
    
    // Should be able to unwrap free tokens
    const freeAmount = parseEther("70");
    await wrapperToken.write.unwrap([freeAmount]);
    
    // Should fail to unwrap locked tokens
    try {
      await wrapperToken.write.unwrap([parseEther("1")]);
      expect.fail("Should have reverted");
    } catch (error) {
      expect(error.message).to.include("InsufficientFreeBalance");
    }
  });

  it("should allow transfer of locked tokens for yield farming", async () => {
    const amount = parseEther("100");
    
    // Wrap tokens
    await mockERC20.write.approve([wrapperToken.address, amount]);
    await wrapperToken.write.wrap([amount]);
    
    // Lock all tokens
    await wrapperToken.write.lockTokens([accounts[0].account.address, amount], {
      account: vault.account
    });
    
    // Should be able to transfer locked tokens (for yield farming)
    await wrapperToken.write.transfer([accounts[1].account.address, amount]);
    
    const balance = await wrapperToken.read.balanceOf([accounts[1].account.address]);
    expect(balance).to.equal(amount);
  });
});
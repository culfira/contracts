import assert from "node:assert/strict";
import { describe, it, before } from "node:test";
import { network } from "hardhat";
import { parseEther, zeroAddress, getAddress } from "viem";

describe("WrapperToken", async function () {
  const { viem, ignition } = await network.connect();
  const publicClient = await viem.getPublicClient();
  let owner: any;
  let treasury: any;
  let user1: any;
  let user2: any;
  let user3: any;
  let vault1: any;
  let vault2: any;

  let underlyingToken: any;
  let wrapperToken: any;

  const MINT_AMOUNT = parseEther("1000");
  const WRAP_AMOUNT = parseEther("500");

  before(async function () {
    const accounts = await viem.getWalletClients();
    [owner, treasury, user1, user2, user3, vault1, vault2] = accounts;

    // Deploy a mock ERC20 token as underlying
    underlyingToken = await viem.deployContract("MockERC20", [
      "Mock Token",
      "MOCK",
      parseEther("1000000") // 1M total supply
    ]);

    // Deploy WrapperToken
    wrapperToken = await viem.deployContract("WrapperToken", [
      underlyingToken.address,
      "Wrapped Mock Token",
      "wMOCK"
    ]);

    // Mint underlying tokens to users
    await underlyingToken.write.transfer([user1.account.address, MINT_AMOUNT]);
    await underlyingToken.write.transfer([user2.account.address, MINT_AMOUNT]);
    await underlyingToken.write.transfer([user3.account.address, MINT_AMOUNT]);
  });

  describe("Deployment", function () {
    it("Should set correct name and symbol", async function () {
      const name = await wrapperToken.read.name();
      const symbol = await wrapperToken.read.symbol();

      assert.equal(name, "Wrapped Mock Token");
      assert.equal(symbol, "wMOCK");
    });

    it("Should set correct underlying token", async function () {
      const underlying = await wrapperToken.read.underlying();
      assert.equal(
        underlying.toLowerCase(),
        underlyingToken.address.toLowerCase()
      );
    });

    it("Should set correct owner", async function () {
      const tokenOwner = await wrapperToken.read.owner();
      assert.equal(
        tokenOwner.toLowerCase(),
        owner.account.address.toLowerCase()
      );
    });
  });

  describe("Wrapping and Unwrapping", function () {
    it("Should wrap underlying tokens", async function () {
      const user1Underlying = await viem.getContractAt(
        "MockERC20",
        underlyingToken.address,
        { client: { wallet: user1 } }
      );
      await user1Underlying.write.approve([wrapperToken.address, WRAP_AMOUNT]);

      const user1Wrapper = await viem.getContractAt(
        "WrapperToken",
        wrapperToken.address,
        { client: { wallet: user1 } }
      );
      await user1Wrapper.write.wrap([WRAP_AMOUNT]);

      const wrapperBalance = await wrapperToken.read.balanceOf([user1.account.address]);
      assert.equal(wrapperBalance, WRAP_AMOUNT);
    });

    it("Should emit Wrapped event", async function () {
      const user2Underlying = await viem.getContractAt(
        "MockERC20",
        underlyingToken.address,
        { client: { wallet: user2 } }
      );
      await user2Underlying.write.approve([wrapperToken.address, WRAP_AMOUNT]);

      const user2Wrapper = await viem.getContractAt(
        "WrapperToken",
        wrapperToken.address,
        { client: { wallet: user2 } }
      );

      await viem.assertions.emitWithArgs(
        user2Wrapper.write.wrap([WRAP_AMOUNT]),
        wrapperToken,
        "Wrapped",
        [getAddress(user2.account.address), WRAP_AMOUNT]
      );
    });

    it("Should unwrap wrapper tokens", async function () {
      const user1Wrapper = await viem.getContractAt(
        "WrapperToken",
        wrapperToken.address,
        { client: { wallet: user1 } }
      );

      const balanceBefore = await underlyingToken.read.balanceOf([user1.account.address]);
      await user1Wrapper.write.unwrap([parseEther("100")]);
      const balanceAfter = await underlyingToken.read.balanceOf([user1.account.address]);

      assert.equal(balanceAfter - balanceBefore, parseEther("100"));
    });

    it("Should revert wrap with zero amount", async function () {
      const user1Wrapper = await viem.getContractAt(
        "WrapperToken",
        wrapperToken.address,
        { client: { wallet: user1 } }
      );

      await assert.rejects(user1Wrapper.write.wrap([0n]));
    });

    it("Should revert unwrap with zero amount", async function () {
      const user1Wrapper = await viem.getContractAt(
        "WrapperToken",
        wrapperToken.address,
        { client: { wallet: user1 } }
      );

      await assert.rejects(user1Wrapper.write.unwrap([0n]));
    });
  });

  describe("Vault Authorization", function () {
    it("Should authorize vault by owner", async function () {
      await wrapperToken.write.authorizeVault([vault1.account.address]);
      const isAuthorized = await wrapperToken.read.authorizedVaults([vault1.account.address]);
      assert.equal(isAuthorized, true);
    });

    it("Should emit VaultAuthorized event", async function () {
      await viem.assertions.emitWithArgs(
        wrapperToken.write.authorizeVault([vault2.account.address]),
        wrapperToken,
        "VaultAuthorized",
        [getAddress(vault2.account.address)]
      );
    });

    it("Should revoke vault authorization", async function () {
      await wrapperToken.write.revokeVault([vault1.account.address]);
      const isAuthorized = await wrapperToken.read.authorizedVaults([vault1.account.address]);
      assert.equal(isAuthorized, false);
    });

    it("Should revert if non-owner tries to authorize", async function () {
      const user1Wrapper = await viem.getContractAt(
        "WrapperToken",
        wrapperToken.address,
        { client: { wallet: user1 } }
      );

      await assert.rejects(
        user1Wrapper.write.authorizeVault([vault1.account.address])
      );
    });
  });

  describe("Token Locking", function () {
    before(async function () {
      // Re-authorize vault2 for locking tests
      await wrapperToken.write.authorizeVault([vault2.account.address]);
    });

    it("Should lock tokens by authorized vault", async function () {
      const lockAmount = parseEther("200");
      
      const vault2Wrapper = await viem.getContractAt(
        "WrapperToken",
        wrapperToken.address,
        { client: { wallet: vault2 } }
      );

      await vault2Wrapper.write.lockTokens([user2.account.address, lockAmount]);

      const locked = await wrapperToken.read.getLockedBalance([
        user2.account.address,
        vault2.account.address
      ]);
      const totalLocked = await wrapperToken.read.totalLocked([user2.account.address]);

      assert.equal(locked, lockAmount);
      assert.equal(totalLocked, lockAmount);
    });

    it("Should emit TokensLocked event", async function () {
      const lockAmount = parseEther("100");
      
      // First user3 needs to wrap tokens
      const user3Underlying = await viem.getContractAt(
        "MockERC20",
        underlyingToken.address,
        { client: { wallet: user3 } }
      );
      const user3Wrapper = await viem.getContractAt(
        "WrapperToken",
        wrapperToken.address,
        { client: { wallet: user3 } }
      );
      
      await user3Underlying.write.approve([wrapperToken.address, lockAmount]);
      await user3Wrapper.write.wrap([lockAmount]);
      
      const vault2Wrapper = await viem.getContractAt(
        "WrapperToken",
        wrapperToken.address,
        { client: { wallet: vault2 } }
      );

      await viem.assertions.emitWithArgs(
        vault2Wrapper.write.lockTokens([user3.account.address, lockAmount]),
        wrapperToken,
        "TokensLocked",
        [getAddress(user3.account.address), getAddress(vault2.account.address), lockAmount]
      );
    });

    it("Should unlock tokens by authorized vault", async function () {
      const unlockAmount = parseEther("50");
      
      const vault2Wrapper = await viem.getContractAt(
        "WrapperToken",
        wrapperToken.address,
        { client: { wallet: vault2 } }
      );

      await vault2Wrapper.write.unlockTokens([user2.account.address, unlockAmount]);

      const locked = await wrapperToken.read.getLockedBalance([
        user2.account.address,
        vault2.account.address
      ]);
      const totalLocked = await wrapperToken.read.totalLocked([user2.account.address]);

      assert.equal(locked, parseEther("150")); // 200 - 50
      assert.equal(totalLocked, parseEther("150"));
    });

    it("Should revert if unauthorized vault tries to lock", async function () {
      const user1Wrapper = await viem.getContractAt(
        "WrapperToken",
        wrapperToken.address,
        { client: { wallet: user1 } }
      );

      await assert.rejects(
        user1Wrapper.write.lockTokens([user2.account.address, parseEther("100")])
      );
    });

    it("Should revert if trying to lock more than balance", async function () {
      const vault2Wrapper = await viem.getContractAt(
        "WrapperToken",
        wrapperToken.address,
        { client: { wallet: vault2 } }
      );

      await assert.rejects(
        vault2Wrapper.write.lockTokens([user2.account.address, parseEther("1000")])
      );
    });
  });

  describe("Transfer Restrictions", function () {
    it("Should allow transfer of unlocked tokens", async function () {
      const user1Wrapper = await viem.getContractAt(
        "WrapperToken",
        wrapperToken.address,
        { client: { wallet: user1 } }
      );

      const transferAmount = parseEther("50");
      await user1Wrapper.write.transfer([user3.account.address, transferAmount]);

      const balance = await wrapperToken.read.balanceOf([user3.account.address]);
      assert.equal(balance >= transferAmount, true);
    });

    it("Should revert transfer of locked tokens", async function () {
      const user2Wrapper = await viem.getContractAt(
        "WrapperToken",
        wrapperToken.address,
        { client: { wallet: user2 } }
      );

      // user2 has 150 locked out of 500 total, so 350 free
      // Try to transfer more than free amount
      await assert.rejects(
        user2Wrapper.write.transfer([user1.account.address, parseEther("400")])
      );
    });

    it("Should revert unwrap of locked tokens", async function () {
      const user2Wrapper = await viem.getContractAt(
        "WrapperToken",
        wrapperToken.address,
        { client: { wallet: user2 } }
      );

      // Try to unwrap more than free balance
      await assert.rejects(
        user2Wrapper.write.unwrap([parseEther("400")])
      );
    });
  });

  describe("View Functions", function () {
    it("Should return correct free balance", async function () {
      const freeBalance = await wrapperToken.read.freeBalanceOf([user2.account.address]);
      const totalBalance = await wrapperToken.read.balanceOf([user2.account.address]);
      const totalLocked = await wrapperToken.read.totalLocked([user2.account.address]);

      assert.equal(freeBalance, totalBalance - totalLocked);
    });

    it("Should return correct locked balance for vault", async function () {
      const lockedBalance = await wrapperToken.read.getLockedBalance([
        user2.account.address,
        vault2.account.address
      ]);
      
      assert.equal(lockedBalance, parseEther("150"));
    });
  });
});
import assert from "node:assert/strict";
import { describe, it, before } from "node:test";
import { network } from "hardhat";
import { parseEther, zeroAddress, getAddress } from "viem";
import { deployCulfiraWithIgnition } from "./fixtures.js";

const MIN_STAKE = parseEther("1000");
const HBAR_BACKING = parseEther("950"); // 95%

describe("CulfiraToken", async function () {
  const { viem, ignition } = await network.connect();
  const publicClient = await viem.getPublicClient();
  let owner: any;
  let treasury: any;
  let user1: any;
  let user2: any;
  let user3: any;
  let user4: any;
  let user5: any;
  let user6: any;
  let user7: any;

  let culToken: any;
  let manager: any;
  let vaultStokvel: any;

  before(async function () {
    // Deploy contracts via Hardhat Ignition fixture
    const {
      token,
      manager: mgr,
      vault,
      accounts,
    } = await deployCulfiraWithIgnition(viem, ignition);
    culToken = token;
    manager = mgr;
    vaultStokvel = vault;

    // Align test accounts with fixture accounts
    owner = accounts.owner;
    treasury = accounts.treasury;
    [user1, user2, user3, user4, user5, user6, user7] = accounts.others;

    // Register the EOA owner as a vault for lock/unlock tests
    await culToken.write.registerVault([owner.account.address, true]);
  });

  describe("Deployment", function () {
    it("Should set correct name and symbol", async function () {
      const name = await culToken.read.name();
      const symbol = await culToken.read.symbol();

      assert.equal(name, "Culfira Token");
      assert.equal(symbol, "CUL");
    });

    it("Should set correct owner", async function () {
      const tokenOwner = await culToken.read.owner();
      // Ownership was transferred to the manager in setup
      assert.equal(
        tokenOwner.toLowerCase(),
        owner.account.address.toLowerCase()
      );
    });

    it("Should set treasury address", async function () {
      const tokenTreasury = await culToken.read.treasury();
      assert.equal(
        tokenTreasury.toLowerCase(),
        treasury.account.address.toLowerCase()
      );
    });
  });

  describe("Minting", function () {
    it("Should mint tokens with correct HBAR backing", async function () {
      const mintAmount = MIN_STAKE;

      await culToken.write.mint([user1.account.address, mintAmount], {
        value: HBAR_BACKING,
      });

      const balance = await culToken.read.balanceOf([user1.account.address]);
      assert.equal(balance, mintAmount);
    });

    it("Should revert if insufficient HBAR backing", async function () {
      const mintAmount = MIN_STAKE;
      const insufficientBacking = parseEther("900");

      await assert.rejects(
        culToken.write.mint([user2.account.address, mintAmount], {
          value: insufficientBacking,
        })
      );
    });

    it("Should transfer HBAR to treasury", async function () {
      const mintAmount = MIN_STAKE;
      const treasuryBalanceBefore = await publicClient.getBalance({
        address: treasury.account.address,
      });

      await culToken.write.mint([user2.account.address, mintAmount], {
        value: HBAR_BACKING,
      });

      const treasuryBalanceAfter = await publicClient.getBalance({
        address: treasury.account.address,
      });

      assert.equal(treasuryBalanceAfter - treasuryBalanceBefore, HBAR_BACKING);
    });
  });

  describe("Vault Registration", function () {
    it("Should register vault by owner", async function () {
      await culToken.write.registerVault([vaultStokvel.address, true]);
      const isVault = await culToken.read.isVault([vaultStokvel.address]);
      assert.equal(isVault, true);
    });

    it("Should revert if non-owner tries to register vault", async function () {
      const user1Token = await viem.getContractAt(
        "CulfiraToken",
        culToken.address,
        { client: { wallet: user1 } }
      );
      await assert.rejects(
        user1Token.write.registerVault([vaultStokvel.address, true])
      );
    });

    it("Should emit VaultRegistered event", async function () {
      await viem.assertions.emitWithArgs(
        culToken.write.registerVault([vaultStokvel.address, false]),
        culToken,
        "VaultRegistered",
        [getAddress(vaultStokvel.address), false]
      );
      await viem.assertions.emitWithArgs(
        culToken.write.registerVault([vaultStokvel.address, true]),
        culToken,
        "VaultRegistered",
        [getAddress(vaultStokvel.address), true]
      );
    });
  });

  describe("Lock Mechanism", function () {
    it("Should lock tokens by registered vault", async function () {
      await culToken.write.mint([user3.account.address, MIN_STAKE], {
        value: HBAR_BACKING,
      });

      const user3Token = await viem.getContractAt(
        "CulfiraToken",
        culToken.address,
        { client: { wallet: user3 } }
      );
      await user3Token.write.approve([owner.account.address, MIN_STAKE]);

      const ownerAsVaultToken = await viem.getContractAt(
        "CulfiraToken",
        culToken.address,
        { client: { wallet: owner } }
      );
      await ownerAsVaultToken.write.transferFrom([
        user3.account.address,
        owner.account.address, // Transfer to vault (owner)
        MIN_STAKE,
      ]);

      await ownerAsVaultToken.write.lock([user3.account.address, MIN_STAKE]);

      const locked = await culToken.read.lockedBalance([user3.account.address]);
      const available = await culToken.read.availableBalance([
        user3.account.address,
      ]);
      const userBalance = await culToken.read.balanceOf([
        user3.account.address,
      ]);

      assert.equal(locked, MIN_STAKE); // Staking tracked
      assert.equal(userBalance, 0n); // User wallet empty
      assert.equal(available, 0n); // Available = balanceOf = 0
    });

    it("Should revert if non-vault tries to lock", async function () {
      await culToken.write.mint([user4.account.address, MIN_STAKE], {
        value: HBAR_BACKING,
      });

      const user4Token = await viem.getContractAt(
        "CulfiraToken",
        culToken.address,
        { client: { wallet: user4 } }
      );

      await assert.rejects(
        user4Token.write.lock([user4.account.address, MIN_STAKE])
      );
    });

    it("Should unlock tokens by registered vault", async function () {
      // 1. Mint và transfer tokens
      await culToken.write.mint([user6.account.address, MIN_STAKE], {
        value: HBAR_BACKING,
      });

      const user6Token = await viem.getContractAt(
        "CulfiraToken",
        culToken.address,
        { client: { wallet: user6 } }
      );
      await user6Token.write.approve([owner.account.address, MIN_STAKE]);

      const ownerAsVaultToken = await viem.getContractAt(
        "CulfiraToken",
        culToken.address,
        { client: { wallet: owner } }
      );

      // 2. Transfer to vault
      await ownerAsVaultToken.write.transferFrom([
        user6.account.address,
        owner.account.address,
        MIN_STAKE,
      ]);

      // 3. Lock
      await ownerAsVaultToken.write.lock([user6.account.address, MIN_STAKE]);

      // 4. Unlock
      await ownerAsVaultToken.write.unlock([user6.account.address, MIN_STAKE]);

      // 5. Transfer back to user
      await ownerAsVaultToken.write.transfer([
        user6.account.address,
        MIN_STAKE,
      ]);

      // 6. Verify
      const locked = await culToken.read.lockedBalance([user6.account.address]);
      const available = await culToken.read.availableBalance([
        user6.account.address,
      ]);
      const userBalance = await culToken.read.balanceOf([
        user6.account.address,
      ]);

      assert.equal(locked, 0n);
      assert.equal(userBalance, MIN_STAKE);
      assert.equal(available, MIN_STAKE);
    });

    it("Should emit TokensLocked event", async function () {
      // Setup: mint, approve, transfer
      await culToken.write.mint([user3.account.address, MIN_STAKE], {
        value: HBAR_BACKING,
      });

      const user3Token = await viem.getContractAt(
        "CulfiraToken",
        culToken.address,
        { client: { wallet: user3 } }
      );
      await user3Token.write.approve([owner.account.address, MIN_STAKE]);

      const ownerAsVaultToken = await viem.getContractAt(
        "CulfiraToken",
        culToken.address,
        { client: { wallet: owner } }
      );

      await ownerAsVaultToken.write.transferFrom([
        user3.account.address,
        owner.account.address,
        MIN_STAKE,
      ]);

      // Test event
      await viem.assertions.emitWithArgs(
        ownerAsVaultToken.write.lock([user3.account.address, MIN_STAKE]),
        culToken,
        "TokensLocked",
        [getAddress(user3.account.address), MIN_STAKE]
      );
    });
  });

  describe("Transfer Hook", function () {
    it("Should allow transfer of unlocked tokens", async function () {
      await culToken.write.mint([user4.account.address, MIN_STAKE], {
        value: HBAR_BACKING,
      });

      const user1Token = await viem.getContractAt(
        "CulfiraToken",
        culToken.address,
        {
          client: { wallet: user4 },
        }
      );

      await user1Token.write.transfer([
        user5.account.address,
        parseEther("500"),
      ]);

      const user2Balance = await culToken.read.balanceOf([
        user5.account.address,
      ]);
      assert.equal(user2Balance, parseEther("500"));
    });

    it("Should revert transfer of locked tokens", async function () {
      await culToken.write.mint([user7.account.address, MIN_STAKE], {
        value: HBAR_BACKING,
      });
      // Register EOA vault and lock
      await culToken.write.registerVault([owner.account.address, true]);
      const ownerAsVaultToken = await viem.getContractAt(
        "CulfiraToken",
        culToken.address,
        { client: { wallet: owner } }
      );
      const lockHash3 = await ownerAsVaultToken.write.lock([
        user7.account.address,
        MIN_STAKE,
      ]);
      await publicClient.waitForTransactionReceipt({ hash: lockHash3 });

      const user1Token = await viem.getContractAt(
        "CulfiraToken",
        culToken.address,
        {
          client: { wallet: user7 },
        }
      );

      await assert.rejects(
        user1Token.write.transfer([user2.account.address, parseEther("500")])
      );
    });

    it("Should allow vault to transfer locked tokens", async function () {
      await culToken.write.mint([user1.account.address, MIN_STAKE], {
        value: HBAR_BACKING,
      });
      await culToken.write.registerVault([owner.account.address, true]);
      const ownerAsVaultToken2 = await viem.getContractAt(
        "CulfiraToken",
        culToken.address,
        { client: { wallet: owner } }
      );
      const lockHash4 = await ownerAsVaultToken2.write.lock([
        user1.account.address,
        MIN_STAKE,
      ]);
      await publicClient.waitForTransactionReceipt({ hash: lockHash4 });

      const user1Token = await viem.getContractAt(
        "CulfiraToken",
        culToken.address,
        {
          client: { wallet: user1 },
        }
      );
      const txHash = await user1Token.write.transfer([
        owner.account.address,
        MIN_STAKE,
      ]);
      await publicClient.waitForTransactionReceipt({ hash: txHash });

      const vaultBalance = await culToken.read.balanceOf([
        owner.account.address,
      ]);
      assert.equal(vaultBalance, MIN_STAKE * 3n);
    });
  });

  describe("Treasury Management", function () {
    it("Should allow owner to update treasury", async function () {
      await culToken.write.setTreasury([user1.account.address]);

      const newTreasury = await culToken.read.treasury();
      assert.equal(
        newTreasury.toLowerCase(),
        user1.account.address.toLowerCase()
      );

      // Reset
      await culToken.write.setTreasury([treasury.account.address]);
    });

    it("Should revert if setting zero address treasury", async function () {
      await assert.rejects(culToken.write.setTreasury([zeroAddress]));
    });

    it("Should revert if non-owner tries to update treasury", async function () {
      const user1Token = await viem.getContractAt(
        "CulfiraToken",
        culToken.address,
        {
          client: { wallet: user1 },
        }
      );

      await assert.rejects(
        user1Token.write.setTreasury([user2.account.address])
      );
    });

    it("Should emit TreasuryUpdated event", async function () {
      await viem.assertions.emitWithArgs(
        culToken.write.setTreasury([user2.account.address]),
        culToken,
        "TreasuryUpdated",
        [getAddress(user2.account.address)]
      );

      // Reset
      await culToken.write.setTreasury([treasury.account.address]);
    });
  });
});

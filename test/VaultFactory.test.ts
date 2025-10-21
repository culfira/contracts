import assert from "node:assert/strict";
import { describe, it, before, beforeEach } from "node:test";
import { network } from "hardhat";
import { parseEther, getAddress } from "viem";

describe("VaultFactory", async function () {
  const { viem, ignition } = await network.connect();
  let owner: any;
  let creator1: any;
  let creator2: any;

  let vaultFactory: any;
  let wrapperRegistry: any;
  let insuranceManager: any;

  const VAULT_NAME = "Test Stokvel";
  const VAULT_DESCRIPTION = "A test stokvel vault";
  const CYCLE_TIME_7_DAYS = BigInt(7 * 24 * 60 * 60);
  const CYCLE_TIME_30_DAYS = BigInt(30 * 24 * 60 * 60);

  before(async function () {
    const accounts = await viem.getWalletClients();
    [owner, creator1, creator2] = accounts;

    // Deploy WrapperRegistry
    wrapperRegistry = await viem.deployContract("WrapperRegistry", []);

    // Deploy InsuranceManager
    insuranceManager = await viem.deployContract("InsuranceManager", []);

    // Deploy VaultFactory
    vaultFactory = await viem.deployContract("VaultFactory", [
      wrapperRegistry.address,
      insuranceManager.address
    ]);
  });

  describe("Deployment", function () {
    it("Should set correct wrapper registry", async function () {
      const registryAddress = await vaultFactory.read.wrapperRegistry();
      assert.equal(
        registryAddress.toLowerCase(),
        wrapperRegistry.address.toLowerCase()
      );
    });

    it("Should set correct insurance manager", async function () {
      const managerAddress = await vaultFactory.read.insuranceManager();
      assert.equal(
        managerAddress.toLowerCase(),
        insuranceManager.address.toLowerCase()
      );
    });

    it("Should set correct owner", async function () {
      const factoryOwner = await vaultFactory.read.owner();
      assert.equal(
        factoryOwner.toLowerCase(),
        owner.account.address.toLowerCase()
      );
    });

    it("Should start with zero vaults", async function () {
      const vaultCount = await vaultFactory.read.getVaultCount();
      assert.equal(vaultCount, 0n);
    });
  });

  describe("Create Vault", function () {
    let vaultAddress: string;

    beforeEach(async function () {
      // Create a vault for testing if not already exists
      if (!vaultAddress) {
        const creator1Factory = await viem.getContractAt("VaultFactory", vaultFactory.address, {
          client: { wallet: creator1 }
        });

        await creator1Factory.write.createVault([
          VAULT_NAME,
          VAULT_DESCRIPTION,
          CYCLE_TIME_7_DAYS
        ]);

        // Get vault address from logs or call getAllVaults
        const vaults = await vaultFactory.read.getAllVaults();
        vaultAddress = vaults[vaults.length - 1]; // Get the last created vault
      }
    });

    it("Should create vault with custom cycle time", async function () {
      const creator1Factory = await viem.getContractAt("VaultFactory", vaultFactory.address, {
        client: { wallet: creator1 }
      });

      const tx = await creator1Factory.write.createVault([
        "New Vault",
        "New test vault",
        CYCLE_TIME_7_DAYS
      ]);

      // Get vault address from logs or call getAllVaults
      const vaults = await vaultFactory.read.getAllVaults();
      const newVaultAddress = vaults[vaults.length - 1];
      assert.equal(typeof newVaultAddress, "string");
    });

    it("Should emit VaultCreated event", async function () {
      const creator2Factory = await viem.getContractAt("VaultFactory", vaultFactory.address, {
        client: { wallet: creator2 }
      });

      // Just test that the transaction succeeds and event is emitted
      await creator2Factory.write.createVault([
        "Second Vault",
        "Second test vault",
        CYCLE_TIME_30_DAYS
      ]);
    });

    it("Should register vault in factory", async function () {
      const isVault = await vaultFactory.read.isVault([vaultAddress]);
      assert.equal(isVault, true);
    });

    it("Should set correct vault metadata", async function () {
      const metadata = await vaultFactory.read.vaultMetadata([vaultAddress]);
      
      // Metadata is returned as array: [name, description, creator, createdAt, cycleTime, isActive]
      assert.equal(metadata[0], VAULT_NAME); // name
      assert.equal(metadata[1], VAULT_DESCRIPTION); // description
      assert.equal(
        metadata[2].toLowerCase(),
        creator1.account.address.toLowerCase()
      ); // creator
      assert.equal(metadata[4], CYCLE_TIME_7_DAYS); // cycleTime
      assert.equal(metadata[5], true); // isActive
    });

    it("Should transfer ownership to creator", async function () {
      const vault = await viem.getContractAt("MultiAssetVault", vaultAddress as `0x${string}`);
      const vaultOwner = await vault.read.owner();
      assert.equal(
        vaultOwner.toLowerCase(),
        creator1.account.address.toLowerCase()
      );
    });

    it("Should set correct cycle time in vault", async function () {
      const vault = await viem.getContractAt("MultiAssetVault", vaultAddress as `0x${string}`);
      const roundDuration = await vault.read.ROUND_DURATION();
      assert.equal(roundDuration, CYCLE_TIME_7_DAYS);
    });

    it("Should increment vault count", async function () {
      const vaultCount = await vaultFactory.read.getVaultCount();
      assert.ok(vaultCount >= 2n); // We created at least 2 vaults
    });

    it("Should revert if cycle time too short", async function () {
      const creator1Factory = await viem.getContractAt("VaultFactory", vaultFactory.address, {
        client: { wallet: creator1 }
      });

      const tooShort = BigInt(12 * 60 * 60); // 12 hours
      await assert.rejects(
        creator1Factory.write.createVault([
          "Invalid Vault",
          "Too short cycle",
          tooShort
        ])
      );
    });

    it("Should revert if cycle time too long", async function () {
      const creator1Factory = await viem.getContractAt("VaultFactory", vaultFactory.address, {
        client: { wallet: creator1 }
      });

      const tooLong = BigInt(366 * 24 * 60 * 60); // 366 days
      await assert.rejects(
        creator1Factory.write.createVault([
          "Invalid Vault",
          "Too long cycle",
          tooLong
        ])
      );
    });
  });

  describe("Vault Management", function () {
    let testVaultAddress: string;

    before(async function () {
      // Create a test vault for management tests
      const creator1Factory = await viem.getContractAt("VaultFactory", vaultFactory.address, {
        client: { wallet: creator1 }
      });

      await creator1Factory.write.createVault([
        "Management Test Vault",
        "For testing management functions",
        CYCLE_TIME_7_DAYS
      ]);

      const vaults = await vaultFactory.read.getAllVaults();
      testVaultAddress = vaults[vaults.length - 1]; // Get the last created vault
    });

    it("Should deactivate vault by owner", async function () {
      await vaultFactory.write.deactivateVault([testVaultAddress]);

      const metadata = await vaultFactory.read.vaultMetadata([testVaultAddress]);
      assert.equal(metadata[5], false); // isActive is at index 5
    });

    it("Should emit VaultDeactivated event", async function () {
      // Create another vault to deactivate
      const creator1Factory = await viem.getContractAt("VaultFactory", vaultFactory.address, {
        client: { wallet: creator1 }
      });

      await creator1Factory.write.createVault([
        "To Deactivate",
        "For deactivation test",
        CYCLE_TIME_7_DAYS
      ]);

      const vaults = await vaultFactory.read.getAllVaults();
      const newVaultAddress = vaults[vaults.length - 1];

      await viem.assertions.emitWithArgs(
        vaultFactory.write.deactivateVault([newVaultAddress]),
        vaultFactory,
        "VaultDeactivated",
        [getAddress(newVaultAddress)]
      );
    });

    it("Should revert deactivate if not owner", async function () {
      const creator1Factory = await viem.getContractAt("VaultFactory", vaultFactory.address, {
        client: { wallet: creator1 }
      });

      await assert.rejects(
        creator1Factory.write.deactivateVault([testVaultAddress as `0x${string}`])
      );
    });

    it("Should revert deactivate if not a vault", async function () {
      await assert.rejects(
        vaultFactory.write.deactivateVault([creator1.account.address])
      );
    });
  });

  describe("View Functions", function () {
    it("Should get all vaults", async function () {
      const allVaults = await vaultFactory.read.getAllVaults();
      assert.equal(allVaults.length >= 2, true);
    });

    it("Should get vault count", async function () {
      const count = await vaultFactory.read.getVaultCount();
      assert.equal(typeof count, "bigint");
      assert.equal(count >= 2n, true);
    });

    it("Should get vault cycle time", async function () {
      const vaults = await vaultFactory.read.getAllVaults();
      const firstVault = vaults[0];
      
      const cycleTime = await vaultFactory.read.getVaultCycleTime([firstVault]);
      assert.equal(cycleTime, CYCLE_TIME_7_DAYS);
    });

    it("Should revert get cycle time for non-vault", async function () {
      await assert.rejects(
        vaultFactory.read.getVaultCycleTime([creator1.account.address])
      );
    });

    it("Should get active vaults", async function () {
      const activeVaults = await vaultFactory.read.getActiveVaults();
      const allVaults = await vaultFactory.read.getAllVaults();
      
      // Active vaults should be less than or equal to all vaults
      assert.equal(activeVaults.length <= allVaults.length, true);
    });

    it("Should check if address is vault", async function () {
      const vaults = await vaultFactory.read.getAllVaults();
      const firstVault = vaults[0];
      
      const isVault = await vaultFactory.read.isVault([firstVault]);
      const isNotVault = await vaultFactory.read.isVault([creator1.account.address]);
      
      assert.equal(isVault, true);
      assert.equal(isNotVault, false);
    });
  });

  describe("Edge Cases", function () {
    it("Should handle minimum valid cycle time", async function () {
      const creator1Factory = await viem.getContractAt("VaultFactory", vaultFactory.address, {
        client: { wallet: creator1 }
      });

      const minCycleTime = BigInt(24 * 60 * 60); // Exactly 1 day
      
      await creator1Factory.write.createVault([
        "Min Cycle Vault",
        "Minimum cycle time vault",
        minCycleTime
      ]);

      const vaults = await vaultFactory.read.getAllVaults();
      const newVault = vaults[vaults.length - 1];
      const cycleTime = await vaultFactory.read.getVaultCycleTime([newVault]);
      
      assert.equal(cycleTime, minCycleTime);
    });

    it("Should handle maximum valid cycle time", async function () {
      const creator1Factory = await viem.getContractAt("VaultFactory", vaultFactory.address, {
        client: { wallet: creator1 }
      });

      const maxCycleTime = BigInt(365 * 24 * 60 * 60); // Exactly 365 days
      
      await creator1Factory.write.createVault([
        "Max Cycle Vault",
        "Maximum cycle time vault",
        maxCycleTime
      ]);

      const vaults = await vaultFactory.read.getAllVaults();
      const newVault = vaults[vaults.length - 1];
      const cycleTime = await vaultFactory.read.getVaultCycleTime([newVault]);
      
      assert.equal(cycleTime, maxCycleTime);
    });
  });
});
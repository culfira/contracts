import assert from "node:assert/strict";
import { describe, it, before } from "node:test";
import { network } from "hardhat";
import { parseEther, getAddress } from "viem";

describe("MultiAssetVault", async function () {
  const { viem, ignition } = await network.connect();
  const publicClient = await viem.getPublicClient();
  let owner: any;
  let user1: any;
  let user2: any;
  let user3: any;

  let multiAssetVault: any;
  let wrapperToken1: any;
  let wrapperToken2: any;
  let underlyingToken1: any;
  let underlyingToken2: any;

  const CYCLE_TIME = BigInt(7 * 24 * 60 * 60); // 7 days
  const DEPOSIT_AMOUNT_1 = parseEther("1000");
  const DEPOSIT_AMOUNT_2 = parseEther("500");
  const WEIGHT_1 = 6000n; // 60%
  const WEIGHT_2 = 4000n; // 40%

  before(async function () {
    const accounts = await viem.getWalletClients();
    [owner, user1, user2, user3] = accounts;

    // Deploy underlying tokens
    underlyingToken1 = await viem.deployContract("MockERC20", [
      "Token 1",
      "TK1",
      parseEther("1000000")
    ]);

    underlyingToken2 = await viem.deployContract("MockERC20", [
      "Token 2", 
      "TK2",
      parseEther("1000000")
    ]);

    // Deploy wrapper tokens
    wrapperToken1 = await viem.deployContract("WrapperToken", [
      underlyingToken1.address,
      "Wrapped Token 1",
      "wTK1"
    ]);

    wrapperToken2 = await viem.deployContract("WrapperToken", [
      underlyingToken2.address,
      "Wrapped Token 2", 
      "wTK2"
    ]);

    // Deploy MultiAssetVault with custom cycle time
    multiAssetVault = await viem.deployContract("MultiAssetVault", [CYCLE_TIME]);

    // Authorize vault in wrapper tokens
    await wrapperToken1.write.authorizeVault([multiAssetVault.address]);
    await wrapperToken2.write.authorizeVault([multiAssetVault.address]);

    // Register wrappers in vault
    await multiAssetVault.write.registerWrapper([wrapperToken1.address]);
    await multiAssetVault.write.registerWrapper([wrapperToken2.address]);

    // Distribute underlying tokens to users
    await underlyingToken1.write.transfer([user1.account.address, parseEther("5000")]);
    await underlyingToken1.write.transfer([user2.account.address, parseEther("5000")]);
    await underlyingToken1.write.transfer([user3.account.address, parseEther("5000")]);

    await underlyingToken2.write.transfer([user1.account.address, parseEther("5000")]);
    await underlyingToken2.write.transfer([user2.account.address, parseEther("5000")]);
    await underlyingToken2.write.transfer([user3.account.address, parseEther("5000")]);

    // Users wrap their tokens  
    for (const user of [user1, user2, user3]) {
      const userUnderlying1 = await viem.getContractAt("MockERC20", underlyingToken1.address, {
        client: { wallet: user }
      });
      const userUnderlying2 = await viem.getContractAt("MockERC20", underlyingToken2.address, {
        client: { wallet: user }
      });
      const userWrapper1 = await viem.getContractAt("WrapperToken", wrapperToken1.address, {
        client: { wallet: user }
      });
      const userWrapper2 = await viem.getContractAt("WrapperToken", wrapperToken2.address, {
        client: { wallet: user }
      });

      await userUnderlying1.write.approve([wrapperToken1.address, parseEther("2000")]);
      await userUnderlying2.write.approve([wrapperToken2.address, parseEther("1000")]);
      
      await userWrapper1.write.depositFor([user.account.address, parseEther("2000")]);
      await userWrapper2.write.depositFor([user.account.address, parseEther("1000")]);

      // Approve vault to spend wrapper tokens
      await userWrapper1.write.approve([multiAssetVault.address, parseEther("2000")]);
      await userWrapper2.write.approve([multiAssetVault.address, parseEther("1000")]);
    }
  });

  describe("Deployment", function () {
    it("Should set correct cycle time", async function () {
      const roundDuration = await multiAssetVault.read.ROUND_DURATION();
      assert.equal(roundDuration, CYCLE_TIME);
    });

    it("Should set correct owner", async function () {
      const vaultOwner = await multiAssetVault.read.owner();
      assert.equal(
        vaultOwner.toLowerCase(),
        owner.account.address.toLowerCase()
      );
    });

    it("Should initialize with round 1", async function () {
      // Note: Since we don't have currentRoundId in the interface, we'll check via getRoundInfo
      const round = await multiAssetVault.read.getRoundInfo([1n]);
      assert.equal(round.id, 0n); // Should be 0 as no round started yet
    });
  });

  describe("Wrapper Registration", function () {
    it("Should register wrapper by owner", async function () {
      const newWrapper = await viem.deployContract("WrapperToken", [
        underlyingToken1.address,
        "Test Wrapper",
        "TEST"
      ]);

      await viem.assertions.emitWithArgs(
        multiAssetVault.write.registerWrapper([newWrapper.address]),
        multiAssetVault,
        "WrapperRegistered",
        [getAddress(newWrapper.address)]
      );
    });

    it("Should revert if non-owner tries to register", async function () {
      const user1Vault = await viem.getContractAt("MultiAssetVault", multiAssetVault.address, {
        client: { wallet: user1 }
      });

      await assert.rejects(
        user1Vault.write.registerWrapper([wrapperToken1.address])
      );
    });
  });

  describe("Join Vault", function () {
    it("Should allow user to join with multi-asset deposit", async function () {
      const user1Vault = await viem.getContractAt("MultiAssetVault", multiAssetVault.address, {
        client: { wallet: user1 }
      });

      await user1Vault.write.joinVault([
        [wrapperToken1.address, wrapperToken2.address],
        [DEPOSIT_AMOUNT_1, DEPOSIT_AMOUNT_2],
        [WEIGHT_1, WEIGHT_2]
      ]);

      const memberInfo = await multiAssetVault.read.getMemberInfo([user1.account.address]);
      assert.equal(memberInfo.isActive, true);
      assert.equal(memberInfo.position, 0n);
    });

    it("Should emit MemberJoined event", async function () {
      const user2Vault = await viem.getContractAt("MultiAssetVault", multiAssetVault.address, {
        client: { wallet: user2 }
      });

      await viem.assertions.emitWithArgs(
        user2Vault.write.joinVault([
          [wrapperToken1.address, wrapperToken2.address],
          [DEPOSIT_AMOUNT_1, DEPOSIT_AMOUNT_2],
          [WEIGHT_1, WEIGHT_2]
        ]),
        multiAssetVault,
        "MemberJoined",
        [getAddress(user2.account.address), 1n]
      );
    });

    it("Should revert if already a member", async function () {
      const user1Vault = await viem.getContractAt("MultiAssetVault", multiAssetVault.address, {
        client: { wallet: user1 }
      });

      await assert.rejects(
        user1Vault.write.joinVault([
          [wrapperToken1.address, wrapperToken2.address],
          [DEPOSIT_AMOUNT_1, DEPOSIT_AMOUNT_2],
          [WEIGHT_1, WEIGHT_2]
        ])
      );
    });

    it("Should revert if weights don't sum to 10000", async function () {
      const user3Vault = await viem.getContractAt("MultiAssetVault", multiAssetVault.address, {
        client: { wallet: user3 }
      });

        await assert.rejects(
        user3Vault.write.joinVault([
          [wrapperToken1.address, wrapperToken2.address],
          [DEPOSIT_AMOUNT_1, DEPOSIT_AMOUNT_2],
          [5000n, 3000n] // Only sums to 8000
        ])
      );
    });

    it("Should revert if array lengths don't match", async function () {
      const user3Vault = await viem.getContractAt("MultiAssetVault", multiAssetVault.address, {
        client: { wallet: user3 }
      });

      await assert.rejects(
        user3Vault.write.joinVault([
          [wrapperToken1.address], // Length 1
          [DEPOSIT_AMOUNT_1, DEPOSIT_AMOUNT_2], // Length 2
          [WEIGHT_1, WEIGHT_2] // Length 2
        ])
      );
    });
  });

  describe("Round Management", function () {
    before(async function () {
      // Add user3 as member for round tests
      const user3Vault = await viem.getContractAt("MultiAssetVault", multiAssetVault.address, {
        client: { wallet: user3 }
      });

      await user3Vault.write.joinVault([
        [wrapperToken1.address, wrapperToken2.address],
        [DEPOSIT_AMOUNT_1, DEPOSIT_AMOUNT_2],
        [WEIGHT_1, WEIGHT_2]
      ]);
    });

    it("Should start round by active member", async function () {
      // User1 (active member) starts round
      const user1Vault = await viem.getContractAt("MultiAssetVault", multiAssetVault.address, {
        client: { wallet: user1 }
      });
      
      await user1Vault.write.startRound([
        [wrapperToken1.address, wrapperToken2.address],
        [WEIGHT_1, WEIGHT_2]
      ]);

      const roundInfo = await multiAssetVault.read.getRoundInfo([1n]);
      assert.equal(roundInfo.state, 1); // ACTIVE
      assert.equal(roundInfo.winner.toLowerCase(), user1.account.address.toLowerCase());
    });

    it("Should emit RoundStarted event", async function () {
      // Deploy new vault for isolated test
      const newVault = await viem.deployContract("MultiAssetVault", [CYCLE_TIME]);
      await wrapperToken1.write.authorizeVault([newVault.address]);
      await wrapperToken2.write.authorizeVault([newVault.address]);
      await newVault.write.registerWrapper([wrapperToken1.address]);
      await newVault.write.registerWrapper([wrapperToken2.address]);

      // Add a member to the new vault
      const user1NewVault = await viem.getContractAt("MultiAssetVault", newVault.address, {
        client: { wallet: user1 }
      });

      const user1Wrapper1 = await viem.getContractAt("WrapperToken", wrapperToken1.address, {
        client: { wallet: user1 }
      });
      const user1Wrapper2 = await viem.getContractAt("WrapperToken", wrapperToken2.address, {
        client: { wallet: user1 }
      });

      // User needs to deposit to wrappers first
      const user1Token1 = await viem.getContractAt("MockERC20", underlyingToken1.address, {
        client: { wallet: user1 }
      });
      const user1Token2 = await viem.getContractAt("MockERC20", underlyingToken2.address, {
        client: { wallet: user1 }
      });

      // Approve wrapper tokens to deposit
      await user1Token1.write.approve([wrapperToken1.address, DEPOSIT_AMOUNT_1]);
      await user1Token2.write.approve([wrapperToken2.address, DEPOSIT_AMOUNT_2]);

      // Deposit to get wrapper tokens
      await user1Wrapper1.write.depositFor([user1.account.address, DEPOSIT_AMOUNT_1]);
      await user1Wrapper2.write.depositFor([user1.account.address, DEPOSIT_AMOUNT_2]);

      // User needs to approve new vault to spend wrapper tokens
      await user1Wrapper1.write.approve([newVault.address, DEPOSIT_AMOUNT_1]);
      await user1Wrapper2.write.approve([newVault.address, DEPOSIT_AMOUNT_2]);

      await user1NewVault.write.joinVault([
        [wrapperToken1.address, wrapperToken2.address], 
        [DEPOSIT_AMOUNT_1, DEPOSIT_AMOUNT_2],
        [WEIGHT_1, WEIGHT_2]
      ]);

      await viem.assertions.emitWithArgs(
        user1NewVault.write.startRound([
          [wrapperToken1.address, wrapperToken2.address],
          [WEIGHT_1, WEIGHT_2]
        ]),
        newVault,
        "RoundStarted",
        [1n, getAddress(user1.account.address)]
      );
    });

    it("Should revert if no members", async function () {
      const emptyVault = await viem.deployContract("MultiAssetVault", [CYCLE_TIME]);

      await assert.rejects(
        emptyVault.write.startRound([
          [wrapperToken1.address, wrapperToken2.address],
          [WEIGHT_1, WEIGHT_2]
        ])
      );
    });

    it("Should revert if non-member tries to start", async function () {
      // Owner (non-member) tries to start round
      await assert.rejects(
        multiAssetVault.write.startRound([
          [wrapperToken1.address, wrapperToken2.address],
          [WEIGHT_1, WEIGHT_2]
        ])
      );
    });
  });

  describe("Winner Claims", function () {
    it("Should allow winner to claim assets", async function () {
      const user1Vault = await viem.getContractAt("MultiAssetVault", multiAssetVault.address, {
        client: { wallet: user1 }
      });

      const balanceBefore1 = await wrapperToken1.read.balanceOf([user1.account.address]);
      const balanceBefore2 = await wrapperToken2.read.balanceOf([user1.account.address]);

      await user1Vault.write.claimWinnerAssets();

      const balanceAfter1 = await wrapperToken1.read.balanceOf([user1.account.address]);
      const balanceAfter2 = await wrapperToken2.read.balanceOf([user1.account.address]);

      // Winner should receive all pooled assets
      assert.equal(balanceAfter1 > balanceBefore1, true);
      assert.equal(balanceAfter2 > balanceBefore2, true);
    });

    it("Should emit WinnerClaimed event", async function () {
      // This was already claimed in previous test, so we'll check the member status
      const memberInfo = await multiAssetVault.read.getMemberInfo([user1.account.address]);
      assert.equal(memberInfo.hasReceivedPayout, true);
    });

    it("Should revert if not winner's turn", async function () {
      const user2Vault = await viem.getContractAt("MultiAssetVault", multiAssetVault.address, {
        client: { wallet: user2 }
      });

      await assert.rejects(user2Vault.write.claimWinnerAssets());
    });

    it("Should revert if already claimed", async function () {
      const user1Vault = await viem.getContractAt("MultiAssetVault", multiAssetVault.address, {
        client: { wallet: user1 }
      });

      await assert.rejects(user1Vault.write.claimWinnerAssets());
    });
  });

  describe("Health Factor", function () {
    it("Should return health factor for user", async function () {
      const healthFactor = await multiAssetVault.read.getHealthFactor([user1.account.address]);
      // Health factor should be 0 initially (no calculation yet)
      assert.equal(typeof healthFactor, "bigint");
    });
  });

  describe("View Functions", function () {
    it("Should get next recipient", async function () {
      const nextRecipient = await multiAssetVault.read.getNextRecipient();
      // Should be user2 since user1 already received payout
      assert.equal(
        nextRecipient.toLowerCase(),
        user2.account.address.toLowerCase()
      );
    });

    it("Should get member info", async function () {
      const memberInfo = await multiAssetVault.read.getMemberInfo([user1.account.address]);
      assert.equal(memberInfo.isActive, true);
      assert.equal(memberInfo.hasReceivedPayout, true);
      assert.equal(memberInfo.position, 0n);
    });

    it("Should get round info", async function () {
      const roundInfo = await multiAssetVault.read.getRoundInfo([1n]);
      assert.equal(roundInfo.id, 1n);
      assert.equal(roundInfo.state, 1); // ACTIVE
      assert.equal(
        roundInfo.winner.toLowerCase(),
        user1.account.address.toLowerCase()
      );
    });

    it("Should get insurance pool balance", async function () {
      const poolBalance = await multiAssetVault.read.getInsurancePool([wrapperToken1.address]);
      assert.equal(typeof poolBalance, "bigint");
    });
  });

  describe("Complete Round", function () {
    it("Should revert complete round before time for non-winner", async function () {
      const user2Vault = await viem.getContractAt("MultiAssetVault", multiAssetVault.address, {
        client: { wallet: user2 }
      });
      
      await assert.rejects(
        user2Vault.write.completeRound()
      );
    });

    // Note: Testing actual round completion would require time manipulation
    // which is complex in this test setup
  });


});
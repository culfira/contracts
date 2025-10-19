import assert from "node:assert/strict";
import { describe, it, before } from "node:test";
import { network } from "hardhat";
import { parseEther, maxUint256, getAddress } from "viem";

const MIN_STAKE = parseEther("1000");
const HBAR_BACKING = parseEther("950");
const ROUND_DURATION = 30n * 24n * 60n * 60n; // 30 days

describe("VaultStokvel", async function () {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const wallets = await viem.getWalletClients();
  
  const [owner, treasury, manager, user1, user2, user3, user4, user5, user6, user7, user8, user9, user10] = wallets;

  let culToken: any;
  let managerContract: any;
  let vaultStokvel: any;

  before(async function () {
    // Deploy Token
    culToken = await viem.deployContract("CulfiraToken", [
      treasury.account.address,
    ]);

    // Deploy Manager
    managerContract = await viem.deployContract("CulfiraManager", [
      culToken.address,
      treasury.account.address,
    ]);

    // Create a primary Vault managed by EOA `manager` and register it
    vaultStokvel = await viem.deployContract("VaultStokvel", [
      culToken.address,
      manager.account.address,
    ]);
    await culToken.write.registerVault([vaultStokvel.address, true]);

    // Mint smaller amounts - only what's needed for initial tests
    // We'll mint more in individual tests as needed
    const initialStake = MIN_STAKE * 3n; // 3x stake for main flow
    const initialBacking = HBAR_BACKING * 3n;
    
    await culToken.write.mint([user1.account.address, initialStake], {
      value: initialBacking,
    });
    await culToken.write.mint([user2.account.address, initialStake], {
      value: initialBacking,
    });
    await culToken.write.mint([user3.account.address, initialStake], {
      value: initialBacking,
    });

    // Approve vault with sufficient allowance
    const user1Token = await viem.getContractAt("CulfiraToken", culToken.address, {
      client: { wallet: user1 },
    });
    const user2Token = await viem.getContractAt("CulfiraToken", culToken.address, {
      client: { wallet: user2 },
    });
    const user3Token = await viem.getContractAt("CulfiraToken", culToken.address, {
      client: { wallet: user3 },
    });

    await user1Token.write.approve([vaultStokvel.address, initialStake]);
    await user2Token.write.approve([vaultStokvel.address, initialStake]);
    await user3Token.write.approve([vaultStokvel.address, initialStake]);
  });

  describe("Deployment", function () {
    it("Should set correct token and manager", async function () {
      const tokenAddress = await vaultStokvel.read.culToken();
      const managerAddress = await vaultStokvel.read.manager();

      assert.equal(tokenAddress.toLowerCase(), culToken.address.toLowerCase());
      assert.equal(
        managerAddress.toLowerCase(),
        manager.account.address.toLowerCase()
      );
    });

    it("Should initialize with round 1", async function () {
      const currentRound = await vaultStokvel.read.currentRound();
      assert.equal(currentRound, 1n);
    });
  });

  describe("Join Vault", function () {
    it("Should allow user to join vault", async function () {
      const user1Vault = await viem.getContractAt(
        "VaultStokvel",
        vaultStokvel.address,
        {
          client: { wallet: user1 },
        }
      );

      await user1Vault.write.joinVault([MIN_STAKE]);

      const member = await vaultStokvel.read.getMemberInfo([
        user1.account.address,
      ]);
      assert.equal(member.stakedAmount, MIN_STAKE);
      assert.equal(member.isActive, true);
    });

    it("Should increment total members and total staked", async function () {
      const user2Vault = await viem.getContractAt(
        "VaultStokvel",
        vaultStokvel.address,
        {
          client: { wallet: user2 },
        }
      );

      await user2Vault.write.joinVault([MIN_STAKE]);

      const totalMembers = await vaultStokvel.read.totalMembers();
      const totalStaked = await vaultStokvel.read.totalStaked();

      assert.equal(totalMembers, 2n);
      assert.equal(totalStaked, MIN_STAKE * 2n);
    });

    it("Should revert if below minimum stake", async function () {
      const user3Vault = await viem.getContractAt(
        "VaultStokvel",
        vaultStokvel.address,
        {
          client: { wallet: user3 },
        }
      );

      const belowMin = parseEther("500");
      await assert.rejects(user3Vault.write.joinVault([belowMin]));
    });

    it("Should revert if already a member", async function () {
      const user1Vault = await viem.getContractAt(
        "VaultStokvel",
        vaultStokvel.address,
        {
          client: { wallet: user1 },
        }
      );

      await assert.rejects(user1Vault.write.joinVault([MIN_STAKE]));
    });

    it("Should emit MemberJoined event", async function () {
      const user3Vault = await viem.getContractAt(
        "VaultStokvel",
        vaultStokvel.address,
        {
          client: { wallet: user3 },
        }
      );

      await viem.assertions.emitWithArgs(
        user3Vault.write.joinVault([MIN_STAKE]),
        vaultStokvel,
        "MemberJoined",
        [getAddress(user3.account.address), MIN_STAKE, 2n]
      );
    });

    it("Should lock tokens after joining", async function () {
      const locked = await culToken.read.lockedBalance([
        user1.account.address,
      ]);
      assert.equal(locked, MIN_STAKE);
    });
  });

  describe("Start Round", function () {
    it("Should allow manager to start round", async function () {
      const managerVault = await viem.getContractAt(
        "VaultStokvel",
        vaultStokvel.address,
        { client: { wallet: manager } }
      );
      await managerVault.write.startRound();

      const round = await vaultStokvel.read.getCurrentRound();
      assert.equal(round.state, 1); // ACTIVE
    });

    it("Should set correct recipient", async function () {
      const round = await vaultStokvel.read.getCurrentRound();
      assert.equal(
        round.recipient.toLowerCase(),
        user1.account.address.toLowerCase()
      );
    });

    it("Should emit RoundStarted event", async function () {
      // Create isolated vault for this test
      const newVault = await viem.deployContract("VaultStokvel", [
        culToken.address,
        manager.account.address,
      ]);
      await culToken.write.registerVault([newVault.address, true]);

      // Use user4 with separate wallet client for minting to avoid owner balance issues
      const user4Token = await viem.getContractAt("CulfiraToken", culToken.address, {
        client: { wallet: user4 },
      });
      
      // User4 mints their own tokens (paying with their own wallet)
      await user4Token.write.mint([user4.account.address, MIN_STAKE], {
        value: HBAR_BACKING,
      });
      await user4Token.write.approve([newVault.address, MIN_STAKE]);

      const user4NewVault = await viem.getContractAt(
        "VaultStokvel",
        newVault.address,
        {
          client: { wallet: user4 },
        }
      );
      await user4NewVault.write.joinVault([MIN_STAKE]);

      const managerNewVault = await viem.getContractAt(
        "VaultStokvel",
        newVault.address,
        {
          client: { wallet: manager },
        }
      );

      await viem.assertions.emit(
        managerNewVault.write.startRound(),
        newVault,
        "RoundStarted"
      );
    });

    it("Should revert if no members", async function () {
      const emptyVault = await viem.deployContract("VaultStokvel", [
        culToken.address,
        manager.account.address,
      ]);
      await culToken.write.registerVault([emptyVault.address, true]);

      const managerEmptyVault = await viem.getContractAt(
        "VaultStokvel",
        emptyVault.address,
        {
          client: { wallet: manager },
        }
      );

      await assert.rejects(managerEmptyVault.write.startRound());
    });

    it("Should revert if non-manager tries to start", async function () {
      const user1Vault = await viem.getContractAt(
        "VaultStokvel",
        vaultStokvel.address,
        {
          client: { wallet: user1 },
        }
      );

      await assert.rejects(user1Vault.write.startRound());
    });
  });

  describe("Claim Round CUL", function () {
    it("Should allow recipient to claim full pool", async function () {
      const user1Vault = await viem.getContractAt(
        "VaultStokvel",
        vaultStokvel.address,
        {
          client: { wallet: user1 },
        }
      );

      const balanceBefore = await culToken.read.balanceOf([
        user1.account.address,
      ]);
      await user1Vault.write.claimRoundCUL();
      const balanceAfter = await culToken.read.balanceOf([
        user1.account.address,
      ]);

      assert.equal(balanceAfter - balanceBefore, MIN_STAKE * 3n);
    });

    it("Should create debt for recipient", async function () {
      const debt = await vaultStokvel.read.getDebtInfo([
        user1.account.address,
      ]);
      assert.equal(debt.isActive, true);
      assert.equal(debt.amount, MIN_STAKE * 3n);
    });

    it("Should revert if not recipient's turn", async function () {
      const user2Vault = await viem.getContractAt(
        "VaultStokvel",
        vaultStokvel.address,
        {
          client: { wallet: user2 },
        }
      );

      await assert.rejects(user2Vault.write.claimRoundCUL());
    });

    it("Should change round state to PAYOUT", async function () {
      const round = await vaultStokvel.read.getCurrentRound();
      assert.equal(round.state, 2); // PAYOUT
    });
  });

  describe("Repay Debt", function () {
    it("Should allow user to repay debt", async function () {
      const debtAmount = MIN_STAKE * 3n;

      const user1Token = await viem.getContractAt("CulfiraToken", culToken.address, {
        client: { wallet: user1 },
      });
      await user1Token.write.approve([vaultStokvel.address, debtAmount]);

      const user1Vault = await viem.getContractAt(
        "VaultStokvel",
        vaultStokvel.address,
        {
          client: { wallet: user1 },
        }
      );
      await user1Vault.write.repayDebt();

      const debt = await vaultStokvel.read.getDebtInfo([
        user1.account.address,
      ]);
      assert.equal(debt.isActive, false);
      assert.equal(debt.amount, 0n);
    });

    it("Should mark member as received payout", async function () {
      const member = await vaultStokvel.read.getMemberInfo([
        user1.account.address,
      ]);
      assert.equal(member.hasReceivedPayout, true);
    });

    it("Should revert if no active debt", async function () {
      const user1Vault = await viem.getContractAt(
        "VaultStokvel",
        vaultStokvel.address,
        {
          client: { wallet: user1 },
        }
      );

      await assert.rejects(user1Vault.write.repayDebt());
    });
  });

  describe("Complete Round", function () {
    it("Should allow manager to complete round after debt repaid", async function () {
      const managerVault = await viem.getContractAt(
        "VaultStokvel",
        vaultStokvel.address,
        {
          client: { wallet: manager },
        }
      );

      await managerVault.write.completeRound();

      const currentRound = await vaultStokvel.read.currentRound();
      assert.equal(currentRound, 2n);
    });
  });

  describe("Health Factor", function () {
    it("Should return max health factor if no debt", async function () {
      const hf = await vaultStokvel.read.checkHealthFactor([
        user2.account.address,
      ]);
      assert.equal(hf, maxUint256);
    });

    it("Should calculate health factor correctly", async function () {
      const managerVault = await viem.getContractAt(
        "VaultStokvel",
        vaultStokvel.address,
        {
          client: { wallet: manager },
        }
      );
      await managerVault.write.startRound();

      const user2Vault = await viem.getContractAt(
        "VaultStokvel",
        vaultStokvel.address,
        {
          client: { wallet: user2 },
        }
      );
      await user2Vault.write.claimRoundCUL();

      const hf = await vaultStokvel.read.checkHealthFactor([
        user2.account.address,
      ]);
      assert.ok(hf > 0n);
    });
  });

  describe("Exit Vault", function () {
    it("Should revert if user has active debt", async function () {
      const user2Vault = await viem.getContractAt(
        "VaultStokvel",
        vaultStokvel.address,
        {
          client: { wallet: user2 },
        }
      );

      await assert.rejects(user2Vault.write.exitVault());
    });

    it("Should allow member to exit after repaying debt", async function () {
      const debtAmount = MIN_STAKE * 3n;

      const user2Token = await viem.getContractAt("CulfiraToken", culToken.address, {
        client: { wallet: user2 },
      });
      await user2Token.write.approve([vaultStokvel.address, debtAmount]);

      const user2Vault = await viem.getContractAt(
        "VaultStokvel",
        vaultStokvel.address,
        {
          client: { wallet: user2 },
        }
      );
      await user2Vault.write.repayDebt();
      await user2Vault.write.exitVault();

      const member = await vaultStokvel.read.getMemberInfo([
        user2.account.address,
      ]);
      assert.equal(member.isActive, false);
    });
  });

  describe("Round Cycle Duration", function () {
    it("Should use default ROUND_DURATION when calling startRound", async function () {
      const testVault = await viem.deployContract("VaultStokvel", [
        culToken.address,
        manager.account.address,
      ]);
      await culToken.write.registerVault([testVault.address, true]);

      // User7 mints with their own wallet
      const user7Token = await viem.getContractAt("CulfiraToken", culToken.address, {
        client: { wallet: user7 },
      });
      await user7Token.write.mint([user7.account.address, MIN_STAKE], {
        value: HBAR_BACKING,
      });
      await user7Token.write.approve([testVault.address, MIN_STAKE]);

      const user7TestVault = await viem.getContractAt(
        "VaultStokvel",
        testVault.address,
        {
          client: { wallet: user7 },
        }
      );
      await user7TestVault.write.joinVault([MIN_STAKE]);

      const managerTestVault = await viem.getContractAt(
        "VaultStokvel",
        testVault.address,
        {
          client: { wallet: manager },
        }
      );
      await managerTestVault.write.startRound();

      const round = await testVault.read.getCurrentRound();
      assert.equal(round.cycleDuration, ROUND_DURATION);
    });

    it("Should allow custom cycle duration", async function () {
      const testVault = await viem.deployContract("VaultStokvel", [
        culToken.address,
        manager.account.address,
      ]);
      await culToken.write.registerVault([testVault.address, true]);

      const user8Token = await viem.getContractAt("CulfiraToken", culToken.address, {
        client: { wallet: user8 },
      });
      await user8Token.write.mint([user8.account.address, MIN_STAKE], {
        value: HBAR_BACKING,
      });
      await user8Token.write.approve([testVault.address, MIN_STAKE]);

      const user8TestVault = await viem.getContractAt(
        "VaultStokvel",
        testVault.address,
        {
          client: { wallet: user8 },
        }
      );
      await user8TestVault.write.joinVault([MIN_STAKE]);

      const customDuration = 60n * 24n * 60n * 60n;
      const managerTestVault = await viem.getContractAt(
        "VaultStokvel",
        testVault.address,
        {
          client: { wallet: manager },
        }
      );
      await managerTestVault.write.startRoundWithDuration([customDuration]);

      const round = await testVault.read.getCurrentRound();
      assert.equal(round.cycleDuration, customDuration);
    });

    it("Should revert if custom duration is zero", async function () {
      const testVault = await viem.deployContract("VaultStokvel", [
        culToken.address,
        manager.account.address,
      ]);
      await culToken.write.registerVault([testVault.address, true]);

      const user9Token = await viem.getContractAt("CulfiraToken", culToken.address, {
        client: { wallet: user9 },
      });
      await user9Token.write.mint([user9.account.address, MIN_STAKE], {
        value: HBAR_BACKING,
      });
      await user9Token.write.approve([testVault.address, MIN_STAKE]);

      const user9TestVault = await viem.getContractAt(
        "VaultStokvel",
        testVault.address,
        {
          client: { wallet: user9 },
        }
      );
      await user9TestVault.write.joinVault([MIN_STAKE]);

      const managerTestVault = await viem.getContractAt(
        "VaultStokvel",
        testVault.address,
        {
          client: { wallet: manager },
        }
      );

      await assert.rejects(managerTestVault.write.startRoundWithDuration([0n]));
    });

    it("Should revert if custom duration exceeds 365 days", async function () {
      const testVault = await viem.deployContract("VaultStokvel", [
        culToken.address,
        manager.account.address,
      ]);
      await culToken.write.registerVault([testVault.address, true]);

      const user10Token = await viem.getContractAt("CulfiraToken", culToken.address, {
        client: { wallet: user10 },
      });
      await user10Token.write.mint([user10.account.address, MIN_STAKE], {
        value: HBAR_BACKING,
      });
      await user10Token.write.approve([testVault.address, MIN_STAKE]);

      const user10TestVault = await viem.getContractAt(
        "VaultStokvel",
        testVault.address,
        {
          client: { wallet: user10 },
        }
      );
      await user10TestVault.write.joinVault([MIN_STAKE]);

      const excessiveDuration = 366n * 24n * 60n * 60n;
      const managerTestVault = await viem.getContractAt(
        "VaultStokvel",
        testVault.address,
        {
          client: { wallet: manager },
        }
      );

      await assert.rejects(
        managerTestVault.write.startRoundWithDuration([excessiveDuration])
      );
    });
  });
});
import "dotenv/config";
import { network } from "hardhat";
import { writeEnv } from "./utils/index.js";

async function main() {
  const { viem } = await network.connect();
  const wallets = await viem.getWalletClients();
  const deployer = wallets[0];
  if (!deployer || !deployer.account) {
    throw new Error(
      "No wallet account available. Configure network accounts (e.g., HEDERA_PRIVATE_KEY) or use a keystore compatible with viem."
    );
  }
  const deployerAddress = deployer.account.address as `0x${string}`;

  const treasuryAddress = (process.env.TREASURY_ADDRESS as `0x${string}` | undefined) ?? deployerAddress;
  const managerAddress = (process.env.MANAGER_ADDRESS as `0x${string}` | undefined) ?? deployerAddress;

  console.log("Deploying with:", deployerAddress);

  // 1) Deploy CulfiraToken
  const culToken = await viem.deployContract("CulfiraToken", [treasuryAddress]);
  console.log("CulfiraToken:", culToken.address);

  // 2) Deploy CulfiraManager
  const culfiraManager = await viem.deployContract("CulfiraManager", [
    culToken.address,
    treasuryAddress,
  ]);
  console.log("CulfiraManager:", culfiraManager.address);

  // 3) Deploy VaultStokvel managed by manager
  const vaultStokvel = await viem.deployContract("VaultStokvel", [
    culToken.address,
    managerAddress,
  ]);
  console.log("VaultStokvel:", vaultStokvel.address);

  // 4) Register vault in CulfiraToken
  await culToken.write.registerVault([vaultStokvel.address, true]);
  console.log("Vault registered in CulfiraToken");

  // Optional: Deploy SaucerSwapWrapper if address env provided
  const saucerPM = process.env.SAUCER_PM_ADDRESS as `0x${string}` | undefined;
  const culTokenAddrOverride = process.env.CUL_TOKEN_ADDRESS as `0x${string}` | undefined;
  const whbarAddr = process.env.WHBAR_ADDRESS as `0x${string}` | undefined;

  if (saucerPM && whbarAddr) {
    const saucerWrapper = await viem.deployContract("SaucerSwapWrapper", [
      saucerPM,
      culTokenAddrOverride ?? culToken.address,
      whbarAddr,
    ]);
    console.log("SaucerSwapWrapper:", saucerWrapper.address);
  }

  writeEnv({
    CULFIRA_TOKEN_ADDRESS: culToken.address,
    CULFIRA_MANAGER_ADDRESS: culfiraManager.address,
    VAULT_STOKVEL_ADDRESS: vaultStokvel.address,  
  })
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

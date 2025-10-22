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

  console.log("Deploying Culfira Multi-Asset Vault Protocol with:", deployerAddress);

  // Step 1: Deploy Protocol Registry
  const protocolRegistry = await viem.deployContract("ProtocolRegistry", []);
  console.log("ProtocolRegistry deployed at:", protocolRegistry.address);

  // Step 2: Deploy Wrapper Registry  
  const wrapperRegistry = await viem.deployContract("WrapperRegistry", []);
  console.log("WrapperRegistry deployed at:", wrapperRegistry.address);

  // Step 3: Deploy Insurance Manager
  const insuranceManager = await viem.deployContract("InsuranceManager", []);
  console.log("InsuranceManager deployed at:", insuranceManager.address);

  // Step 4: Deploy Vault Factory with dependencies
  const vaultFactory = await viem.deployContract("VaultFactory", [
    wrapperRegistry.address,
    insuranceManager.address
  ]);
  console.log("VaultFactory deployed at:", vaultFactory.address);

  // Step 5: Deploy wrapper tokens manually and register them
  const wrapperTokens = [];
  
  // Get sample underlying token address from env or deploy a mock token
  let sampleUnderlying: `0x${string}`;
  
  if (process.env.SAMPLE_UNDERLYING_TOKEN) {
    sampleUnderlying = process.env.SAMPLE_UNDERLYING_TOKEN as `0x${string}`;
  } else {
    // Deploy a mock ERC20 token for testing
    const mockToken = await viem.deployContract("MockERC20", [
      "Mock HBAR",
      "HBAR", 
      1000000000000000000000000n // 1M tokens with 18 decimals
    ]);
    sampleUnderlying = mockToken.address;
    console.log("Mock underlying token deployed at:", sampleUnderlying);
  }
  
  // Deploy wrapper token directly instead of using registry factory
  console.log("Deploying wrapper token for:", sampleUnderlying);
  
  const hbarWrapper = await viem.deployContract("WrapperToken", [
    sampleUnderlying,
    "Wrapped HBAR",
    "xHBAR"
  ]);
  console.log("HBAR WrapperToken deployed at:", hbarWrapper.address);
  
  // Set protocol registry in the wrapper token
  await hbarWrapper.write.setProtocolRegistry([protocolRegistry.address]);
  console.log("Protocol registry set in wrapper token");
  
  // Now register the manually deployed wrapper in the registry
  // First, we need to modify WrapperRegistry to accept pre-deployed wrappers
  // For now, let's skip registry registration and continue
  console.log("Skipping registry registration for this deployment");

  wrapperTokens.push({
    name: "HBAR",
    underlying: sampleUnderlying,
    wrapper: hbarWrapper.address
  });

  // Step 6: Create example vault with 7-day cycle using factory
  const cycleTime = BigInt(7 * 24 * 60 * 60); // 7 days as bigint
  console.log("Creating vault with cycle time:", cycleTime.toString());
  
  const vaultTx = await vaultFactory.write.createVault([
    "Example Stokvel Vault",
    "A demonstration vault for multi-asset stokvel rounds", 
    cycleTime
  ]);
  console.log("Vault creation transaction:", vaultTx);

  // Get vault count safely
  const vaultCount = await vaultFactory.read.getVaultCount();
  console.log("Total vaults created:", vaultCount.toString());
  
  // Check if any vaults exist before accessing
  if (vaultCount === 0n) {
    throw new Error("No vaults created - check VaultFactory implementation");
  }

  const latestVaultAddress = await vaultFactory.read.vaults([vaultCount - 1n]);
  console.log("MultiAssetVault created at:", latestVaultAddress);

  // Validate vault creation
  if (latestVaultAddress === "0x0000000000000000000000000000000000000000") {
    throw new Error("Failed to create vault - check VaultFactory implementation");
  }

  writeEnv({
    PROTOCOL_REGISTRY_ADDRESS: protocolRegistry.address,
    WRAPPER_REGISTRY_ADDRESS: wrapperRegistry.address,
    INSURANCE_MANAGER_ADDRESS: insuranceManager.address,
    VAULT_FACTORY_ADDRESS: vaultFactory.address,
    HBAR_WRAPPER_ADDRESS: hbarWrapper.address as string,
    EXAMPLE_VAULT_ADDRESS: latestVaultAddress as string,
    SAMPLE_UNDERLYING_TOKEN: sampleUnderlying,
  });

  console.log("\n🎉 Culfira Protocol deployed successfully!");
  console.log("📋 Summary:");
  console.log("- ProtocolRegistry:", protocolRegistry.address);
  console.log("- WrapperRegistry:", wrapperRegistry.address); 
  console.log("- InsuranceManager:", insuranceManager.address);
  console.log("- VaultFactory:", vaultFactory.address);
  console.log("- Sample Underlying Token:", sampleUnderlying);
  console.log("- Sample HBAR Wrapper:", hbarWrapper.address);
  console.log("- Example Vault:", latestVaultAddress);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
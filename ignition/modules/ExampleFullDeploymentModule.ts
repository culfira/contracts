import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// Example deployment showing how to use all modules together
export default buildModule("ExampleFullDeploymentModule", (m) => {
  // Step 1: Deploy core infrastructure
  const wrapperRegistry = m.contract("WrapperRegistry", []);
  const insuranceManager = m.contract("InsuranceManager", []);
  
  // Step 2: Deploy VaultFactory
  const vaultFactory = m.contract("VaultFactory", [wrapperRegistry, insuranceManager]);
  
  // Step 3: Deploy example underlying token (for testing)
  // In production, you would use existing token address
  const underlyingToken = m.getParameter<string>("underlyingToken");
  
  // Step 4: Deploy WrapperToken for the underlying token
  const wrapperToken = m.contract("WrapperToken", [
    underlyingToken,
    m.getParameter<string>("wrapperName", "Wrapped Token"),
    m.getParameter<string>("wrapperSymbol", "WRAP")
  ]);
  
  // Step 5: Deploy MultiAssetVault with custom cycle time
  const cycleTime = m.getParameter<number>("cycleTime", 7 * 24 * 60 * 60); // Default 7 days
  const multiAssetVault = m.contract("MultiAssetVault", [cycleTime]);

  return { 
    wrapperRegistry,
    insuranceManager,
    vaultFactory,
    wrapperToken,
    multiAssetVault
  };
});
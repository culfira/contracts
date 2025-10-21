import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// Complete deployment module that deploys all contracts in correct order
export default buildModule("CompleteDeploymentModule", (m) => {
  // Deploy supporting contracts first
  const wrapperRegistry = m.contract("WrapperRegistry", []);
  const insuranceManager = m.contract("InsuranceManager", []);
  
  // Deploy VaultFactory with dependencies
  const vaultFactory = m.contract("VaultFactory", [wrapperRegistry, insuranceManager]);

  return { 
    wrapperRegistry, 
    insuranceManager, 
    vaultFactory
  };
});
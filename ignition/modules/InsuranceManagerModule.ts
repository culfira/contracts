import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// Deploys InsuranceManager
export default buildModule("InsuranceManagerModule", (m) => {
  const insuranceManager = m.contract("InsuranceManager", []);

  return { insuranceManager };
});
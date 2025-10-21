import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// Deploys VaultFactory, requires WrapperRegistry and InsuranceManager addresses
export default buildModule("VaultFactoryModule", (m) => {
  const wrapperRegistry = m.getParameter<string>("wrapperRegistry");
  const insuranceManager = m.getParameter<string>("insuranceManager");

  const vaultFactory = m.contract("VaultFactory", [wrapperRegistry, insuranceManager]);

  return { vaultFactory };
});
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// Deploys WrapperRegistry
export default buildModule("WrapperRegistryModule", (m) => {
  const wrapperRegistry = m.contract("WrapperRegistry", []);

  return { wrapperRegistry };
});
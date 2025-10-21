import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// Deploys MultiAssetVault with custom cycle time
export default buildModule("MultiAssetVaultModule", (m) => {
  const cycleTime = m.getParameter<number>("cycleTime", 30 * 24 * 60 * 60); // Default 30 days in seconds

  const multiAssetVault = m.contract("MultiAssetVault", [cycleTime]);

  return { multiAssetVault };
});
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// Deploys CulfiraManager, requires an existing token address and a treasury
export default buildModule("CulfiraManagerModule", (m) => {
  const token = m.getParameter<string>("token");
  const treasury = m.getParameter<string>("treasury");

  const manager = m.contract("CulfiraManager", [token, treasury]);

  return { manager };
});

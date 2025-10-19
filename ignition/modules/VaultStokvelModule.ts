import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// Deploys VaultStokvel with references to the token and manager
export default buildModule("VaultStokvelModule", (m) => {
  const token = m.getParameter<string>("token");
  const manager = m.getParameter<string>("manager");

  const vault = m.contract("VaultStokvel", [token, manager]);

  return { vault };
});

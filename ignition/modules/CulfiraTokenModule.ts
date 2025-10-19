import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// Deploys CulfiraToken with a configurable treasury address
export default buildModule("CulfiraTokenModule", (m) => {
  const treasury = m.getParameter<string>("treasury");

  const token = m.contract("CulfiraToken", [treasury]);

  return { token };
});

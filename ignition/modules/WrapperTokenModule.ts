import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// Deploys WrapperToken, requires underlying token address, name, and symbol
export default buildModule("WrapperTokenModule", (m) => {
  const underlyingToken = m.getParameter<string>("underlyingToken");
  const name = m.getParameter<string>("name");
  const symbol = m.getParameter<string>("symbol");

  const wrapperToken = m.contract("WrapperToken", [underlyingToken, name, symbol]);

  return { wrapperToken };
});
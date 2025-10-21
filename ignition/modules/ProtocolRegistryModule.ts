import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ProtocolRegistryModule = buildModule("ProtocolRegistryModule", (m) => {
  // Deploy ProtocolRegistry
  const protocolRegistry = m.contract("ProtocolRegistry");

  return { protocolRegistry };
});

export default ProtocolRegistryModule;
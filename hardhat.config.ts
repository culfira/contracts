import type { HardhatUserConfig } from "hardhat/config";
import * as dotenv from "dotenv";

import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import hardhatIgnitionViemPlugin from "@nomicfoundation/hardhat-ignition-viem";
import hardhatVerify from "@nomicfoundation/hardhat-verify";
import { configVariable } from "hardhat/config";

dotenv.config();

const config: HardhatUserConfig = {
  plugins: [hardhatVerify, hardhatToolboxViemPlugin, hardhatIgnitionViemPlugin],
  solidity: {
    version: "0.8.28",
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 200,
      },
      outputSelection: {
        "*": {
          "*": ["abi", "evm.bytecode", "evm.deployedBytecode", "metadata"],
        },
      },
    },
  },
  networks: {
    testnet: {
      type: "http",
      url: configVariable("HEDERA_RPC_URL"),
      accounts: [configVariable("HEDERA_PRIVATE_KEY")],
    },
  },
  verify: {
    etherscan: {
      apiKey: process.env.ETHERSCAN_API_KEY || "",
    },
  },
};

export default config;

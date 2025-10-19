import * as dotenv from "dotenv";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

dotenv.config();

// Hedera SaucerSwap NonfungiblePositionManager (example address provided by user)
const SAUCER_PM = process.env.SAUCERSWAP_V2_NONFUNGIBLE_POSITION_MANAGER as `0x${string}`;

const SaucerSwapWrapperModule = buildModule("SaucerSwapWrapperModule", (m) => {
  // params allow overriding addresses if needed
  const positionManager = m.getParameter<`0x${string}`>("positionManager", SAUCER_PM);
  const culToken = m.getParameter<`0x${string}`>("culToken");
  const whbar = m.getParameter<`0x${string}`>("whbar");

  const saucerSwapWrapper = m.contract("SaucerSwapWrapper", [positionManager, culToken, whbar]);

  return { saucerSwapWrapper };
});

export default SaucerSwapWrapperModule;

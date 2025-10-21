import { getAddress, type Address } from "viem";

import WrapperRegistryModule from "../ignition/modules/WrapperRegistryModule.js";
import InsuranceManagerModule from "../ignition/modules/InsuranceManagerModule.js";
import VaultFactoryModule from "../ignition/modules/VaultFactoryModule.js";
import WrapperTokenModule from "../ignition/modules/WrapperTokenModule.js";
import MultiAssetVaultModule from "../ignition/modules/MultiAssetVaultModule.js";

export type NewDeployedContracts = {
  wrapperRegistry: any;
  insuranceManager: any;
  vaultFactory: any;
  wrapperToken?: any;
  multiAssetVault?: any;
  accounts: {
    owner: any;
    others: any[];
  };
};

// Deploy the new contract stack using Hardhat Ignition
export async function deployNewContractsWithIgnition(
  viem: any,
  ignition: any,
  options?: {
    includeWrapperToken?: boolean;
    includeVault?: boolean;
    underlyingToken?: string;
    cycleTime?: bigint;
  }
): Promise<NewDeployedContracts> {
  const accounts = await viem.getWalletClients();
  const [owner, ...others] = accounts;

  // Deploy WrapperRegistry
  const { wrapperRegistry } = (await ignition.deploy(WrapperRegistryModule)) as any;

  // Deploy InsuranceManager
  const { insuranceManager } = (await ignition.deploy(InsuranceManagerModule)) as any;

  // Deploy VaultFactory
  const { vaultFactory } = (await ignition.deploy(VaultFactoryModule, {
    parameters: {
      VaultFactoryModule: {
        wrapperRegistry: wrapperRegistry.address as Address,
        insuranceManager: insuranceManager.address as Address,
      },
    },
  })) as any;

  let wrapperToken;
  let multiAssetVault;

  // Optional: Deploy WrapperToken
  if (options?.includeWrapperToken && options?.underlyingToken) {
    const { wrapperToken: deployedWrapper } = (await ignition.deploy(WrapperTokenModule, {
      parameters: {
        WrapperTokenModule: {
          underlyingToken: getAddress(options.underlyingToken) as Address,
          name: "Test Wrapper Token",
          symbol: "TWP",
        },
      },
    })) as any;
    wrapperToken = deployedWrapper;
  }

  // Optional: Deploy MultiAssetVault
  if (options?.includeVault) {
    const cycleTime = options?.cycleTime || BigInt(30 * 24 * 60 * 60); // Default 30 days
    const { multiAssetVault: deployedVault } = (await ignition.deploy(MultiAssetVaultModule, {
      parameters: {
        MultiAssetVaultModule: {
          cycleTime: cycleTime,
        },
      },
    })) as any;
    multiAssetVault = deployedVault;
  }

  // Return viem-style contract instances
  const wrapperRegistryContract = await viem.getContractAt(
    "WrapperRegistry",
    wrapperRegistry.address
  );
  const insuranceManagerContract = await viem.getContractAt(
    "InsuranceManager",
    insuranceManager.address
  );
  const vaultFactoryContract = await viem.getContractAt(
    "VaultFactory",
    vaultFactory.address
  );

  let wrapperTokenContract;
  let multiAssetVaultContract;

  if (wrapperToken) {
    wrapperTokenContract = await viem.getContractAt(
      "WrapperToken",
      wrapperToken.address
    );
  }

  if (multiAssetVault) {
    multiAssetVaultContract = await viem.getContractAt(
      "MultiAssetVault",
      multiAssetVault.address
    );
  }

  return {
    wrapperRegistry: wrapperRegistryContract,
    insuranceManager: insuranceManagerContract,
    vaultFactory: vaultFactoryContract,
    ...(wrapperTokenContract && { wrapperToken: wrapperTokenContract }),
    ...(multiAssetVaultContract && { multiAssetVault: multiAssetVaultContract }),
    accounts: { owner, others },
  };
}

// Deploy full stack with all components
export async function deployCompleteStackWithIgnition(
  viem: any,
  ignition: any,
  underlyingTokenAddress: string,
  cycleTime?: bigint
): Promise<NewDeployedContracts> {
  return deployNewContractsWithIgnition(viem, ignition, {
    includeWrapperToken: true,
    includeVault: true,
    underlyingToken: underlyingTokenAddress,
    cycleTime: cycleTime || BigInt(7 * 24 * 60 * 60), // Default 7 days
  });
}
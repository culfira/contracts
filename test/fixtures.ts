import { getAddress, type Address } from "viem";

import CulfiraTokenModule from "../ignition/modules/CulfiraTokenModule.js";
import CulfiraManagerModule from "../ignition/modules/CulfiraManagerModule.js";
import VaultStokvelModule from "../ignition/modules/VaultStokvelModule.js";

export type DeployedContracts = {
	token: any;
	manager: any;
	vault: any;
	accounts: {
		owner: any;
		treasury: any;
		others: any[];
	};
};

// Deploy the full stack using Hardhat Ignition and return viem contract instances
export async function deployCulfiraWithIgnition(
	viem: any,
	ignition: any
): Promise<DeployedContracts> {
	const accounts = await viem.getWalletClients();

	const [owner, treasury, ...others] = accounts;

	// Deploy Token
		const { token } = (await ignition.deploy(CulfiraTokenModule, {
		parameters: {
			CulfiraTokenModule: {
				treasury: getAddress(treasury.account.address) as Address,
			},
		},
		})) as any;

	// Deploy Manager
		const { manager } = (await ignition.deploy(CulfiraManagerModule, {
		parameters: {
			CulfiraManagerModule: {
				token: token.address as Address,
				treasury: getAddress(treasury.account.address) as Address,
			},
		},
		})) as any;

	// Deploy Vault
		const { vault } = (await ignition.deploy(VaultStokvelModule, {
		parameters: {
			VaultStokvelModule: {
				token: token.address as Address,
				manager: manager.address as Address,
			},
		},
		})) as any;

	// Return viem-style contract instances
		const tokenContract = await viem.getContractAt(
			"CulfiraToken",
			token.address
		);
	const managerContract = await viem.getContractAt(
		"CulfiraManager",
		manager.address
	);
	const vaultContract = await viem.getContractAt(
		"VaultStokvel",
		vault.address
	);

	return {
		token: tokenContract,
		manager: managerContract,
		vault: vaultContract,
		accounts: { owner, treasury, others },
	};
}


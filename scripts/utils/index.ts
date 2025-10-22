import * as fs from "fs";
import * as path from "path";

export function writeEnv(vars: Record<string, string>) {
  // In ESM, __dirname is not defined. Use process.cwd() (project root when run via Hardhat).
  const envPath = path.resolve(process.cwd(), ".env");
  const lines: string[] = [];

  if (fs.existsSync(envPath)) {
    const existing = fs.readFileSync(envPath, "utf8").split("\n");
    for (const line of existing) {
      if (!line.trim() || line.startsWith("#")) continue;
      const [key] = line.split("=");
      if (!(key in vars)) lines.push(line);
    }
  }

  for (const [key, value] of Object.entries(vars)) {
    lines.push(`${key}=${value}`);
  }

  fs.writeFileSync(envPath, lines.join("\n"), "utf8");
  console.log("✅ Updated .env file with:", Object.keys(vars));
}

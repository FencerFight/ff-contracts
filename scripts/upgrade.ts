import { ethers, upgrades } from "hardhat";
import fs from "fs";
import path from "path";

interface ContractAddresses {
  governance: string;
  fencer: string;
  tournament: string;
  achievementSBT: string;
}

async function main() {
  // 1. Загружаем текущие адреса контрактов
  const addressesPath = path.join(__dirname, "../deployed-addresses.json");
  const addresses: ContractAddresses = JSON.parse(fs.readFileSync(addressesPath, "utf8"));

  const [deployer] = await ethers.getSigners();
  console.log("Upgrading contracts with account:", deployer.address);

  // 2. Последовательно обновляем контракты
  console.log("\n=== Upgrading contracts ===");

  // PlatformGovernance
  const GovernanceFactory = await ethers.getContractFactory("PlatformGovernance");
  console.log("Upgrading PlatformGovernance...");
  const governance = await upgrades.upgradeProxy(
    addresses.governance,
    GovernanceFactory
  );
  await governance.waitForDeployment();
  console.log("PlatformGovernance upgraded:", await governance.getAddress());

  // Fencer
  const FencerFactory = await ethers.getContractFactory("Fencer");
  console.log("Upgrading Fencer...");
  const fencer = await upgrades.upgradeProxy(
    addresses.fencer,
    FencerFactory
  );
  await fencer.waitForDeployment();
  console.log("Fencer upgraded:", await fencer.getAddress());

  // Tournament
  const TournamentFactory = await ethers.getContractFactory("Tournament");
  console.log("Upgrading Tournament...");
  const tournament = await upgrades.upgradeProxy(
    addresses.tournament,
    TournamentFactory
  );
  await tournament.waitForDeployment();
  console.log("Tournament upgraded:", await tournament.getAddress());

  // AchievementSBT
  const SBTFactory = await ethers.getContractFactory("AchievementSBT");
  console.log("Upgrading AchievementSBT...");
  const sbt = await upgrades.upgradeProxy(
    addresses.achievementSBT,
    SBTFactory
  );
  await sbt.waitForDeployment();
  console.log("AchievementSBT upgraded:", await sbt.getAddress());

  // 3. Проверяем связи между контрактами
  console.log("\n=== Verifying dependencies ===");
  await verifyDependencies(governance, fencer, tournament, sbt);

  console.log("\n✅ All contracts upgraded successfully");
}

async function verifyDependencies(governance: any, fencer: any, tournament: any, sbt: any) {
  // Проверка Governance
  const currentFencerAddr = await fencer.getAddress();
  const currentTournamentAddr = await tournament.getAddress();
  await governance.initAddress(currentFencerAddr, currentTournamentAddr)
  console.log(`Governance links:
    Fencer: ${currentFencerAddr}
    Tournament: ${currentTournamentAddr}`);

  // При необходимости обновляем связи
  await tournament.setAchievementSBT(await sbt.getAddress());
  console.log("Updating Tournament SBT link...");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Upgrade failed:", error);
    process.exit(1);
  });